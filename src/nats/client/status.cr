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
  class Client
    enum Status
      # When the client is not actively connected.
      DISCONNECTED

      # When the client is connected.
      CONNECTED

      # When the client will no longer attempt to connect to a NATS Server.
      CLOSED

      # When the client has disconnected and is attempting to reconnect.
      RECONNECTING

      # When the client is attempting to connect to a NATS Server for the first time.
      CONNECTING

      # When the client is draining a connection before closing.
      DRAINING_SUBS

      # :ditto:
      DRAINING_PUBS
    end
  end
end
