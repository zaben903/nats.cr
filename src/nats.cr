require "./nats/*"

module NATS
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  # Connects to a NATS server using the provided URI.
  #
  # *uri*: The URI of the NATS server to connect to.
  def self.connect(uri : String | URI = Client::DEFAULT_URI) : Client
    Client.new(uri).connect
  end

  # :nodoc:
  private CR_LF = "\r\n"
end
