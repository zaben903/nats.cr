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

module NATS
  module Message
    # A client will need to start as a plain TCP connection,
    #   then when the server accepts a connection from the client,
    #   it will send information about itself,
    #   the configuration and security requirements necessary for the client to successfully authenticate with the server and exchange messages.
    #
    # When using the updated client protocol (see `CONNECT`),
    #   INFO messages can be sent anytime by the server.
    #   This means clients with that protocol level need to be able to asynchronously handle INFO messages.
    #
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#info
    struct INFO
      include JSON::Serializable

      # The unique identifier of the NATS server.
      property server_id : String
      # The name of the NATS server.
      property server_name : String
      # The version of NATS.
      property version : String
      # The version of golang the NATS server was built with.
      property go : String
      # The IP address used to start the NATS server, by default this will be 0.0.0.0 and can be configured with -client_advertise host:port.
      property host : String
      # The port number the NATS server is configured to listen on.
      property port : Int32
      # Whether the server supports headers.
      property headers : Bool
      # Maximum payload size, in bytes, that the server will accept from the client.
      property max_payload : Int32
      # An integer indicating the protocol version of the server.
      # The server version 1.2.0 sets this to `1` to indicate that it supports the "Echo" feature.
      property proto : Int32
      # The internal client identifier in the server.
      # This can be used to filter client connections in monitoring, correlate with error logs, etc...
      property client_id : UInt64? = nil
      # If this is true, then the client should try to authenticate upon connect.
      property auth_required : Bool? = false
      # If this is true, then the client must perform the TLS/1.2 handshake.
      # Note, this used to be ssl_required and has been updated along with the protocol from SSL to TLS.
      property tls_required : Bool? = false
      # If this is true, the client must provide a valid certificate during the TLS handshake.
      property tls_verify : Bool? = false
      # If this is true, the client can provide a valid certificate during the TLS handshake.
      property tls_available : Bool? = false
      # List of server urls that a client can connect to.
      property connect_urls : Array(String)? = nil
      # List of server urls that a websocket client can connect to.
      property ws_connect_urls : Array(String)? = nil
      # If the server supports Lame Duck Mode notifications, and the current server has transitioned to lame duck, ldm will be set to true.
      property ldm : Bool? = false
      # The git hash at which the NATS server was built.
      property git_commit : String? = nil
      # Whether the server supports JetStream.
      property jetstream : Bool? = false
      # The IP of the server.
      property ip : String? = nil
      # The IP of the client.
      property client_ip : String? = nil
      # The nonce for use in CONNECT.
      property nonce : String? = nil
      # The name of the cluster.
      property cluster : String? = nil
      # The configured NATS domain of the server.
      property domain : String? = nil
    end
  end
end
