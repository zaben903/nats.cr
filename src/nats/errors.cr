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
  # Generic NATS exception class.
  class Error < Exception
  end

  # +ClientClosed+ is raised when `NATS::Client.status == +NATS::Client::Status::CLOSED`\
  # Usually due to the socket being closed.
  class ClientClosedError < Error
    def initialize(msg = "Client is closed")
      super(msg)
    end
  end

  # +Timeout+ is raised when `NATS::Options.timeout` is reached.
  class TimeoutError < Error
    def initialize(msg = "Timeout occurred")
      super(msg)
    end
  end

  # +-ERR+ is raised when the NATS server indicates a protocol error.
  class ERRError < Error
    def initialize(msg = "Unknown error")
      super(msg)
    end
  end

  # +AuthenticationError+ is raised when the NATS server indicates an authentication error.
  class AuthenticationError < ERRError
    def initialize(msg = "Authentication failed")
      super(msg)
    end
  end

  # +MSGError+ is raised when there is a problem with a +NATS::Message::MSG+.
  class MSGError < Error
    def initialize(msg = "MSG error")
      super(msg)
    end
  end
end
