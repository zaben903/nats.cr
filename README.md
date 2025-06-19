# NATS - Crystal Client

Simple NATS client for the [Crystal](https://crystal-lang.org) programming language.

[![License Apache 2](https://img.shields.io/badge/License-Apache2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Build Status](https://travis-ci.org/nats-io/nats.cr.svg?branch=master)](http://travis-ci.org/nats-io/nats.cr)

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
   dependencies:
     nats:
       github: nats-io/nats.cr
```

2. Run `shards install`

## Usage

```crystal
require "nats/client"

client = NATS::Client.new("nats://localhost:4222")
client.connect

client.subscribe("foo") do |msg|
  puts "Received message on subject #{msg.subject}: #{msg.payload}"
end

client.publish("foo", "Hello, NATS!")

client.subscribe("bar") do |msg|
  msg.reply "Received your message on bar: #{msg.payload}"
end

response = client.request("bar", "Hello, bar!")
puts "Received response: #{response.payload}"

client.request("bar") do |msg|
  puts "Recieved async response: #{msg.payload}"
end

client.close
```

## License

Unless otherwise noted, the NATS source files are distributed under
the Apache Version 2.0 license found in the LICENSE file.
