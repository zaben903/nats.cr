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
    # The PUB message publishes the message payload to the given subject name, optionally supplying a reply subject.\
    # If a reply subject is supplied, it will be delivered to eligible subscribers along with the supplied payload.
    #
    # NOTE: that the payload itself is optional.
    #
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#pub
    struct PUB
      # The destination subject to publish to.
      property subject : String
      # The reply subject that subscribers can use to send a response back to the publisher/requestor.
      property reply_to : String? = nil
      # The message payload data.
      property payload : String? = nil
      # The callback to be invoked when a message is received.
      property callback : (Message::MSG -> Nil)? = nil # TODO: Handle callback

      def initialize(
        @subject : String,
        @reply_to : String? = nil,
        @payload : String? = nil,
        @callback : (Message::MSG -> Nil)? = nil,
      )
        raise ArgumentError.new("Subject cannot be empty") if subject.empty?
      end

      def to_s
        if reply_to.nil?
          "PUB #{subject} #{bytes}#{CR_LF}#{payload}"
        else
          "PUB #{subject} #{reply_to} #{bytes}#{CR_LF}#{payload}"
        end
      end

      private def bytes
        payload.try &.bytesize || 0
      end
    end
  end
end
