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

import ContainerizationOCI
import Foundation

/// A snapshot of a mac-container-tool along with its configuration
/// and any runtime state information.
public struct ContainerSnapshot: Codable, Sendable {
    /// The configuration of the mac-container-tool.
    public var configuration: ContainerConfiguration

    /// Identifier of the mac-container-tool.
    public var id: String {
        configuration.id
    }

    /// Configured platform for the mac-container-tool.
    public var platform: ContainerizationOCI.Platform {
        configuration.platform
    }

    /// The runtime status of the mac-container-tool.
    public var status: RuntimeStatus
    /// Network interfaces attached to the sandbox that are provided to the mac-container-tool.
    public var networks: [Attachment]
    /// When the mac-container-tool was started.
    public var startedDate: Date?

    public init(
        configuration: ContainerConfiguration,
        status: RuntimeStatus,
        networks: [Attachment],
        startedDate: Date? = nil
    ) {
        self.configuration = configuration
        self.status = status
        self.networks = networks
        self.startedDate = startedDate
    }
}
