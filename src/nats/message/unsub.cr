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
    # UNSUB unsubscribes the connection from the specified subject,
    #   or auto-unsubscribes after the specified number of messages has been received.
    #
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#unsub
    struct UNSUB
      # The unique alphanumeric subscription ID of the subject to unsubscribe from.
      property sid : String
      # If specified, the subscriber will join this queue group.
      property max_msgs : Int64? = nil

      def initialize(
        @sid : String,
        @max_msgs : Int64? = nil,
      )
      end

      def to_s
        if max_msgs.nil?
          "UNSUB #{sid}"
        else
          "UNSUB #{sid} #{max_msgs}"
        end
      end
    end
  end
end
