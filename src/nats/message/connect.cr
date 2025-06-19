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
    # The CONNECT message is the client version of the INFO message.\
    # Once the client has established a TCP/IP socket connection with the NATS server,
    #   and an INFO message has been received from the server,
    #   the client may send a CONNECT message to the NATS server to provide more
    #   information about the current connection as well as security information.
    #
    # SEE: https://docs.nats.io/reference/reference-protocols/nats-protocol#connect
    struct CONNECT
      # Turns on +OK protocol acknowledgements.
      property verbose : Bool? = false
      # Turns on additional strict format checking, e.g. for properly formed subjects.
      property pedantic : Bool? = false
      # Indicates whether the client requires an SSL connection.
      property tls_required : Bool? = false
      # Client authorization token.
      property auth_token : String? = nil
      # Connection username.
      property user : String? = nil
      # Connection password.
      property pass : String? = nil
      # Client name.
      property name : String? = nil
      # The implementation language of the client.
      property lang : String? = "crystal"
      # The version of the client.
      property version : String? = NATS::VERSION
      # Sending `0` (or absent) indicates client supports original protocol.
      # Sending `1` indicates that the client supports dynamic reconfiguration
      #   of cluster topology changes by asynchronously receiving INFO messages with known servers it can reconnect to.
      # TODO: Support dynamic reconfiguration in the future
      property protocol : Int32? = 0
      # If set to false, the server (version 1.2.0+) will not send originating messages from this connection to its own subscriptions.
      # Clients should set this to false only for server supporting this feature,
      #   which is when proto in the INFO protocol is set to at least `1`.
      property echo : Bool? = nil
      # In case the server has responded with a nonce on INFO,
      #   then a NATS client must use this field to reply with the signed nonce.
      property sig : String? = nil
      # The JWT that identifies a user permissions and account.
      property jwt : String? = nil
      # Enable quick replies for cases where a request is sent to a topic with no responders.
      property no_responders : Bool? = nil
      # Whether the client supports headers.
      # TODO: Implement headers support
      property headers : Bool? = false
      # The public NKey to authenticate the client.
      # This will be used to verify the signature (sig) against the nonce provided in the INFO message.
      property nkey : String? = nil

      def initialize
      end

      include JSON::Serializable

      def to_s
        "CONNECT #{to_json}"
      end
    end
  end
end
