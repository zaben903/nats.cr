# Copyright 2019-2025 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "json"
require "openssl"
require "random/secure"
require "socket"
require "uri"

require "./errors"
require "./nuid"
require "./options"
require "./client/*"
require "./message/*"

module NATS
  # NATS Client for connecting to a NATS server.\
  # This client allows you to subscribe and publish messages.
  #
  # Example:
  # ```
  # require "nats/client"
  #
  # client = NATS::Client.new("nats://localhost:4222")
  # client.connect
  #
  # client.subscribe("foo") do |msg|
  #   puts "Received message on subject #{msg.subject}: #{msg.payload}"
  # end
  #
  # client.publish("foo", "Hello, NATS!")
  #
  # client.subscribe("bar") do |msg|
  #   msg.reply "Received your message on bar: #{msg.payload}"
  # end
  #
  # response = client.request("bar", "Hello, bar!")
  # puts "Received response: #{response.payload}"
  #
  # client.request("bar") do |msg|
  #   puts "Recieved async response: #{msg.payload}"
  # end
  #
  # client.close
  # ```
  class Client
    # Default Port for NATS Server
    DEFAULT_PORT = 4222
    # Default Host for NATS Server
    DEFAULT_HOST = "localhost"
    # Default URI for NATS Server
    DEFAULT_URI = URI.parse "nats://#{DEFAULT_HOST}:#{DEFAULT_PORT}"
    # Buffer Size for the socket
    BUFFER_SIZE = 32_768

    # The current status of the client connection.
    getter status : Status = Status::DISCONNECTED

    @uri : URI
    @server_info : Message::INFO | Nil
    @subs : Hash(UInt64, Subscription) = Hash(UInt64, Subscription).new
    @sid : UInt64 = 0
    @socket : TCPSocket | OpenSSL::SSL::Socket::Client
    @socket_mutex : Mutex = Mutex.new
    @pongs : Deque(Channel(Nil)) = Deque(Channel(Nil)).new

    def initialize(
      uri : String | URI = DEFAULT_URI,
      @options : Options = Options.new,
      @user : String? = nil,
      @pass : String? = nil,
      @jwt : String? = nil,
    )
      @uri = uri.is_a?(URI) ? uri : URI.parse(uri)
      @user = @uri.user if @user.nil? && @uri.user
      @pass = @uri.password if @pass.nil? && @uri.password
      @socket = uninitialized TCPSocket

      # Inbox setup
      @nuid = NUID.new
      @resp_sub_prefix = "_INBOX.#{@nuid.next}"
    end

    # Connects to the NATS server
    def connect : self
      @status = Status::CONNECTING
      setup_socket

      # Get server info
      handle_info(parse_info(@socket.read_line))

      # Time to connect!
      send_connect
      first_connection_ok?
      @status = Status::CONNECTED

      # Handle inbound messages
      spawn handle_messages
      # Handle async outbound messages
      spawn flush

      self
    end

    # Subscribe to a subject, messages will be delivered to the provided callback.
    #
    # *subject*: The subject to subscribe to.\
    # *queue_group*: Optional queue group for load balancing.\
    # *callback*: The callback to handle incoming messages.
    def subscribe(subject : String, queue_group : String? = nil, &callback : Message::MSG -> Nil) : Subscription
      raise ClientClosedError.new if status == Status::CLOSED

      sid = next_sid
      sub = Subscription.new(
        subject: subject,
        sid: sid,
        callback: callback,
        client: self,
        queue_group: queue_group
      )

      msg = Message::SUB.new(
        subject: subject,
        queue_group: queue_group,
        sid: sid.to_s
      )
      send_msg!(msg.to_s)
      @subs[sid] = sub
    end

    # Unsubscribes from a subject.
    #
    # *sub*: The subscription to unsubscribe from.
    def unsubscribe(sub : Subscription)
      raise ClientClosedError.new if status == Status::CLOSED

      sid = sub.sid
      unsub = Message::UNSUB.new(sid: sid.to_s)
      send_msg!(unsub.to_s)
      @subs.delete(sid)
    end

    # Publishes a message to the specified subject.
    #
    # *subject*: The subject to publish to.\
    # *payload*: The message payload.
    def publish(subject : String, payload : String)
      raise ClientClosedError.new if status == Status::CLOSED

      msg = Message::PUB.new(
        subject: subject,
        payload: payload
      )
      send_msg!(msg.to_s)
    end

    # Publishes a message to the specified subject and waits for a response.
    #
    # *subject*: The subject to publish to.\
    # *payload*: The message payload.\
    # *timeout*: Optional timeout for waiting for a response. Will use `Options.timeout` if not set.
    def request(subject : String, payload : String, timeout : Time::Span? = nil) : Message::MSG
      raise ClientClosedError.new if status == Status::CLOSED

      msg = Message::PUB.new(
        subject: subject,
        reply_to: new_inbox,
        payload: payload
      )
      send_msg!(msg.to_s)
      channel = Channel(Message::MSG).new
      reply_sub = subscribe(msg.reply_to.to_s) do |response_msg|
        channel.send(response_msg)
      end
      spawn do
        sleep timeout || @options.timeout
        channel.close
      end

      begin
        channel.receive
      rescue
        raise TimeoutError.new("Request Timeout")
      end
    ensure
      @subs[reply_sub.try(&.sid)].unsubscribe if @subs.has_key?(reply_sub.try(&.sid))
      @subs.delete(reply_sub.try(&.sid)) if reply_sub.try(&.sid)
    end

    # Publishes a message to the specified subject and sends response to callback when available.
    #
    # *subject*: The subject to publish to.\
    # *payload*: The message payload.\
    # *callback*: Callback to handle the response message.
    def request(subject : String, payload : String, &callback : Message::MSG -> Nil)
      raise ClientClosedError.new if status == Status::CLOSED

      msg = Message::PUB.new(
        subject: subject,
        reply_to: new_inbox,
        payload: payload
      )
      send_msg(msg.to_s)
      spawn do
        channel = Channel(Message::MSG).new
        reply_sub = subscribe(msg.reply_to.to_s) do |response_msg|
          channel.send(response_msg)
        end
        callback.call(channel.receive)
      ensure
        @subs[reply_sub.try(&.sid)].unsubscribe if @subs.has_key?(reply_sub.try(&.sid))
        @subs.delete(reply_sub.try(&.sid)) if reply_sub.try(&.sid)
      end
    end

    # Closes the NATS connection and cleans up resources.
    def close
      return if status == Status::CLOSED

      # Close all subscriptions
      @status = Status::DRAINING_SUBS
      @subs.each_value(&.unsubscribe)
      @subs.clear

      # Holding the mutex to ensure no other operations are performed while closing
      @socket_mutex.synchronize do
        @pongs.each(&.close) # Close all pending PONG channels
        @pongs.clear

        unless @socket.closed?
          @status = Status::DRAINING_PUBS
          @socket.flush
          @socket.close
        end
        @status = Status::CLOSED
      end
    end

    # Checks if the client is connected to the NATS server.\
    # Will send a PING message and wait for a PONG response.
    def connected? : Bool
      return false if status == Status::CLOSED

      channel = Channel(Nil).new
      @pongs.push(channel)
      send_msg!("PING")
      spawn do
        sleep @options.timeout
        channel.close
      end
      channel.receive rescue {raise TimeoutError.new("PING timeout")}
      true
    end

    # Regex patterns for parsing NATS protocol messages from the server

    # INFO - Sent to client after initial TCP/IP connection.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#info
    private INFO = /\AINFO\s+(?<options>[^\r\n]+)/i
    # MSG - Delivers a message payload to a subscriber.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#msg
    private MSG = /\AMSG\s+(?<subject>[^\s]+)\s+(?<sid>[^\s]+)\s+(?:(?<reply>[^\s]+)\s+)?(?<bytes>\d+)/i
    # HMSG - Delivers a message payload to a subscriber with NATS headers.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#hmsg
    private HMSG = /\AHPUB\s+(?<subject>[^\s]+)\s+(?<sid>[^\s]+)\s+(?:(?<reply>[^\s]+)\s+)?(?<header_size>\d+)\s+(?<total_size>\d+)/i
    # PING - keep-alive message.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#ping-pong
    private PING = /\APING\s*/i
    # PONG - keep-alive response.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#ping-pong
    private PONG = /\APONG\s*/i
    # ERR - Indicates a protocol error. May cause client disconnect.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#ok-err
    private ERR = /\A-ERR\s+'(?<message>.+)?'/i
    # OK - Acknowledges well-formed protocol message in verbose mode.\
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#ok-err
    private OK = /\A\+OK\s*/i

    # Handles incoming messages from the server.
    #
    # NOTE: This is intended to be run in a separate fiber.
    private def handle_messages
      until status == Status::CLOSED
        case line = @socket.gets(CR_LF)
        when INFO
          handle_info(parse_info(line.to_s))
        when PING
          send_msg!("PONG")
        when PONG
          channel = @pongs.pop?
          channel.try &.send(nil) # Notify the waiting channel that a PONG was received
        when ERR
          raise ERRError.new($~["message"] || "Unknown error")
        when OK
          next
        when MSG
          bytes = $~["bytes"].to_i64
          if bytes > 0
            payload = Bytes.new(bytes)
            @socket.read_fully(payload)
            payload = String.new(payload)
          else
            payload = nil
          end
          2.times { @socket.read_byte } # Consume the trailing "\r\n" after the payload

          msg = Message::MSG.new(
            subject: $~["subject"],
            sid: $~["sid"].to_i64,
            reply_to: $~["reply"]? || nil,
            payload: payload,
            bytes: bytes,
            client: self
          )
          @subs[msg.sid].callback.call(msg)
        when HMSG
          next # TODO: Handle HMSG
        else
          return close if @socket.closed? || line.nil? # Socket has been closed on us

          raise Error.new("Unexpected response from server: #{line}")
        end
      end
    rescue e : IO::Error
      return if status == Status::CLOSED # The socket may have been closed on us while waiting for messages
      raise e
    rescue e : IO::EOFError
      return close # Socket has been closed on us
    end

    # Parses the INFO message from the server.
    private def parse_info(info : String) : Message::INFO
      if match = INFO.match(info)
        Message::INFO.from_json(match["options"].to_s)
      else
        raise Error.new("Invalid INFO message: #{info}")
      end
    end

    private def handle_info(info : Message::INFO)
      @server_info = info
      tls_upgrade if (@server_info.try(&.tls_required) || @uri.scheme == "tls") && !@socket.is_a?(OpenSSL::SSL::Socket::Client)
    end

    # Sets up the socket connection to the NATS server.
    private def setup_socket
      @socket_mutex.synchronize do
        @socket = TCPSocket.new(@uri.host || DEFAULT_HOST, @uri.port || DEFAULT_PORT)
        @socket.as(TCPSocket).tcp_nodelay = true
        @socket.as(TCPSocket).sync = true
        @socket.as(TCPSocket).read_buffering = true
        @socket.as(TCPSocket).buffer_size = BUFFER_SIZE
        @socket.as(TCPSocket).write_timeout = @options.timeout
      end
    end

    # Upgrades the socket to use TLS if required by the server.
    private def tls_upgrade
      @socket_mutex.synchronize do
        @socket = OpenSSL::SSL::Socket::Client.new(@socket)
        @socket.as(OpenSSL::SSL::Socket::Client).sync_close = true
        @socket.as(OpenSSL::SSL::Socket::Client).sync = true
        @socket.as(OpenSSL::SSL::Socket::Client).read_buffering = true
        @socket.as(OpenSSL::SSL::Socket::Client).buffer_size = BUFFER_SIZE
        @socket.as(OpenSSL::SSL::Socket::Client).write_timeout = @options.timeout
      end
    end

    # Sends a CONNECT message to the NATS server.
    private def send_connect
      msg = Message::CONNECT.new
      msg.pedantic = @options.pedantic
      msg.user = @user if @user
      msg.pass = @pass if @pass
      msg.jwt = @jwt if @jwt
      msg.sig = @server_info.try &.nonce
      msg.tls_required = true if @uri.scheme == "tls"

      send_msg!(msg.to_s)
    end

    # Used during the initial connection to the NATS server.
    private def first_connection_ok? : Bool
      send_msg!("PING")
      read_timeout! do
        case line = @socket.gets(CR_LF)
        when PONG
          true
        when ERR
          if $~["message"] =~ /Authorization Violation\z/
            raise AuthenticationError.new
          else
            raise ERRError.new($~["message"] || "Unknown error")
          end
        else
          raise Error.new("Unexpected response from server: #{line}")
        end
      end
    end

    # Sends a message to the NATS server.\
    # Doesn't wait for other messages to be written to the socket.
    #
    # *msg*: The message to send.
    protected def send_msg!(msg : String)
      raise ClientClosedError.new if status == Status::CLOSED

      @socket_mutex.synchronize do
        @socket.write((msg + CR_LF).to_slice)
        @socket.flush
      end
    end

    # Sends a message to the NATS server to be sent later.
    #
    # *msg*: The message to send.
    protected def send_msg(msg : String)
      raise ClientClosedError.new if status == Status::CLOSED

      @socket_mutex.synchronize do
        @socket.write((msg + CR_LF).to_slice)
      end
    end

    # Flushes the socket periodically to handle async messages.
    #
    # NOTE: This is intended to be run in a separate fiber.
    private def flush
      until status == Status::CLOSED
        @socket_mutex.synchronize do
          @socket.flush
        end
        sleep @options.flush_interval
      end
    end

    private def next_sid : UInt64
      @sid += 1
    end

    # Use the same inbox suffix length as nats.go.\
    # SEE: https://github.com/nats-io/nats.go/blob/8a48023f77877dcfc140d0b9c25603c6cbedfaab/nats.go#L4239
    private TOKEN_LENGTH = 8

    private def new_inbox : String
      reply_sub_suffix = String::Builder.build(TOKEN_LENGTH) do |io|
        Random::Secure.random_bytes(TOKEN_LENGTH).each do |n|
          io << NUID::DIGITS[n % NUID::BASE]
        end
      end
      "#{@resp_sub_prefix}.#{reply_sub_suffix}"
    end

    # Enables temporary read timeout for the socket.\
    # This is useful for operations that may block indefinitely, such as waiting for a PONG response.
    private def read_timeout!(&)
      if @socket.is_a?(OpenSSL::SSL::Socket::Client)
        @socket.as(OpenSSL::SSL::Socket::Client).read_timeout = @options.timeout
      else
        @socket.as(TCPSocket).read_timeout = @options.timeout
      end

      begin
        yield
      ensure
        if @socket.is_a?(OpenSSL::SSL::Socket::Client)
          @socket.as(OpenSSL::SSL::Socket::Client).read_timeout = nil
        else
          @socket.as(TCPSocket).read_timeout = nil
        end
      end
    end
  end
end
