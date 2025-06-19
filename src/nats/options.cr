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
  # Adapted from the nats.go library.
  #
  # NOTE: Currently only some options are implemented.
  #
  # SEE: https://github.com/nats-io/nats.go/blob/8a48023f77877dcfc140d0b9c25603c6cbedfaab/nats.go#L152
  struct Options
    # From nats.go
    # property allow_reconnect : Bool = true
    # property max_reconnect : Int32 = 60
    # property reconnect_wait : Time::Span = 2.seconds
    # property reconnect_jitter : Time::Span = 100.milliseconds
    # property reconnect_jitter_tls : Time::Span = 1.second
    property timeout : Time::Span = 2.seconds
    # property ping_interval : Time::Span = 2.minutes
    # property max_pings_out : Int32 = 2
    # property sub_chan_len : Int32 = 64 * 1024 # 64k
    # property reconnect_buf_size : Int32 = 8 * 1024 * 1024 # 8MB
    # property drain_timeout : Time::Span = 30.seconds
    # property flusher_timeout : Time::Span = 1.minute
    property pedantic : Bool = false

    # Specific to nats.cr
    property flush_interval : Time::Span = 100.milliseconds
  end
end
