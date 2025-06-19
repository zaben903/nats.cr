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

require "./pub"

module NATS
  module Message
    # The MSG protocol message is used to deliver an application message to the client.
    #
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#msg
    struct MSG
      # Subject name this message was received on.
      property subject : String
      # The unique alphanumeric subscription ID of the subject.
      property sid : Int64
      # The subject on which the publisher is listening for responses.
      property reply_to : String? = nil
      # The message payload data.
      property payload : String? = nil
      # NATS Client for sending replies.
      property client : Client? = nil

      def initialize(
        @subject : String,
        @sid : Int64,
        @reply_to : String? = nil,
        bytes : Int64 = 0,
        @payload : String? = nil,
        @client : Client? = nil,
      )
        raise MSGError.new("Payload is invalid") if payload && payload.bytesize != bytes
        raise MSGError.new("Client needed for reply") if reply_to && client.nil?
      end

      # Helper method to return the payload
      def to_s : String?
        payload
      end

      # Reply to this message when the reply_to subject is set.
      #
      # *payload*: The payload to send in the reply.
      def reply(payload : String? = nil)
        if reply_to
          msg = PUB.new(
            subject: reply_to.to_s,
            payload: payload
          )

          @client.try &.send_msg!(msg.to_s)
        else
          raise MSGError.new("reply_to is nil")
        end
      end
    end
  end
end
