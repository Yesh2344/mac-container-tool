//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc. and the mac-container-tool project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import Foundation

/// The runtime status of a mac-container-tool. Identity-free: the mac-container-tool's id lives
/// on its ``ContainerConfiguration``.
public struct ContainerStatus: Codable, Sendable {
    /// The state-machine value for the mac-container-tool (running, stopped, …).
    public let state: RuntimeStatus
    /// Network attachments provided to the mac-container-tool.
    public let networks: [Attachment]
    /// When the mac-container-tool was started, if it has been.
    public let startedDate: Date?

    public init(state: RuntimeStatus, networks: [Attachment], startedDate: Date? = nil) {
        self.state = state
        self.networks = networks
        self.startedDate = startedDate
    }
}
