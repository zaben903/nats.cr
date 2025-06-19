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

require "../spec_helper"

describe NATS::Client do
  uri = URI.parse("nats://127.0.0.1:4322")
  server : NATSServer | Nil = nil

  # Authentication testing
  user = "user"
  pass = "s3cr3t"
  auth_uri = URI.parse("nats://#{user}:#{pass}@127.0.0.1:4333")
  noauth_uri = URI.parse("nats://127.0.0.1:4333")
  auth_server : NATSServer | Nil = nil

  Spec.before_each do
    server = NATSServer.start(uri)
  end

  Spec.after_each do
    server.try(&.shutdown)
    server = nil
    auth_server.try(&.shutdown)
    auth_server = nil
  end

  describe "#connect" do
    it "connects to the NATS server" do
      client = NATS::Client.new(uri).connect
      client.status.should eq NATS::Client::Status::CONNECTED
      client.@socket.closed?.should be_false
      client.close
    end

    it "will upgrade to a TLS connection", tags: "slow" do
      client = NATS::Client.new(URI.parse("tls://demo.nats.io")).connect
      client.@socket.should be_a(OpenSSL::SSL::Socket::Client)
      client.status.should eq NATS::Client::Status::CONNECTED
      client.close
    end

    describe "authentication" do
      it "connects with a User/Pass" do
        auth_server = NATSServer.start(auth_uri)
        client = NATS::Client.new(noauth_uri, user: user, pass: pass).connect
        client.status.should eq NATS::Client::Status::CONNECTED
        client.close
      end

      it "connects with User/Pass URI" do
        auth_server = NATSServer.start(auth_uri)
        client = NATS::Client.new(auth_uri).connect
        client.status.should eq NATS::Client::Status::CONNECTED
        client.close
      end

      it "fails to connect with wrong User/Pass" do
        auth_server = NATSServer.start(auth_uri)
        expect_raises(NATS::AuthenticationError) do
          client = NATS::Client.new(noauth_uri, user: user, pass: "wrong").connect
        end
      end
    end
  end

  describe "*status*" do
    it "is DISCONNECTED when first created" do
      client = NATS::Client.new(uri)
      client.status.should eq NATS::Client::Status::DISCONNECTED
    end

    it "is CONNECTED after connecting" do
      client = NATS::Client.new(uri).connect
      client.status.should eq NATS::Client::Status::CONNECTED
      client.close
    end

    it "is CLOSED after closing" do
      client = NATS::Client.new(uri).connect
      client.close
      client.status.should eq NATS::Client::Status::CLOSED
    end

    it "is CLOSED if the server closes" do
      client = NATS::Client.new(uri).connect
      server.try(&.shutdown)
      sleep 1.millisecond # Allow time for the client to detect the server shutdown
      client.status.should eq NATS::Client::Status::CLOSED
    end
  end

  describe "#connected?" do
    it "is connected to the server" do
      client = NATS::Client.new(uri).connect
      (client.connected?).should be_true
      client.close
    end

    it "is not connected when the socket is closed" do
      client = NATS::Client.new(uri).connect
      client.close
      (client.connected?).should be_false
    end
  end

  describe "#subscribe" do
    it "returns a Subscription object" do
      client = NATS::Client.new(uri).connect
      subject = "spec.nats.client.subscribe"

      subscription = client.subscribe(subject) do |msg|
        # Do nothing
      end

      subscription.should be_a(NATS::Subscription)
      subscription.subject.should eq subject
      client.close
    end

    it "subscribes to a subject and receives messages" do
      client = NATS::Client.new(uri).connect
      subject = "spec.nats.client.subscribe"
      message = "Test message"

      received_messages = [] of String
      client.subscribe(subject) do |msg|
        received_messages << msg.payload.to_s
      end

      client.publish(subject, message)
      sleep 1.millisecond # Allow time for the message to be processed

      received_messages.should eq [message]
      client.close
    end

    it "subscribes and can reply" do
      client = NATS::Client.new(uri).connect
      subject = "spec.nats.client.subscribe"

      client.subscribe(subject) do |msg|
        msg.reply("PONG")
      end

      response = client.request(subject, "PING")

      response.try &.payload.should eq "PONG"
      client.close
    end
  end

  describe "#publish" do
    it "raises an error if subject is empty" do
      client = NATS::Client.new(uri).connect
      expect_raises(ArgumentError) do
        client.publish("", "Test message")
      end
      client.close
    end
  end

  describe "#request" do
    it "should raise +NATS::TimeoutError+ if request takes too long" do
      client = NATS::Client.new(uri).connect
      subject = "spec.nats.client.subscribe"

      client.subscribe(subject) do |msg|
        sleep 10.milliseconds
        msg.reply("PONG")
      rescue
      end

      expect_raises(NATS::TimeoutError) do
        client.request(subject, "PING", 5.milliseconds)
      end

      client.close
    end

    it "should accept async requests" do
      client = NATS::Client.new(uri).connect
      subject = "spec.nats.client.subscribe"

      client.subscribe(subject) do |msg|
        msg.reply("PONG")
      end

      response = ""
      client.request(subject, "PING") do |msg|
        response = "PONG"
      end
      sleep 1.millisecond # Allow time for the async request to be processed
      response.should eq "PONG"

      client.close
    end
  end
end
