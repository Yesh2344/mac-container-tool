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

import ContainerPersistence
import ContainerResource
import ContainerizationOCI
import Foundation

public struct MachineSnapshot: Codable, Sendable {
    public var configuration: MachineConfiguration
    public var status: RuntimeStatus
    public var bootConfig: MachineConfig
    public var startedDate: Date?
    public var createdDate: Date?
    public var mac-container-toolId: String?
    public var ipAddress: String?
    public var diskSize: UInt64?

    public var initialized: Bool

    public var id: String { configuration.id }
    public var platform: ContainerizationOCI.Platform { configuration.platform }

    enum CodingKeys: String, CodingKey {
        case configuration
        case status
        case startedDate
        case createdDate
        case mac-container-toolId
        case bootConfig
        case ipAddress
        case diskSize
        case initialized
    }

    public init(
        configuration: MachineConfiguration,
        status: RuntimeStatus,
        bootConfig: MachineConfig,
        startedDate: Date? = nil,
        createdDate: Date? = nil,
        mac-container-toolId: String? = nil,
        ipAddress: String? = nil,
        diskSize: UInt64? = nil,
        initialized: Bool = false,
    ) {
        self.configuration = configuration
        self.status = status
        self.bootConfig = bootConfig
        self.startedDate = startedDate
        self.createdDate = createdDate
        self.mac-container-toolId = mac-container-toolId
        self.ipAddress = ipAddress
        self.diskSize = diskSize
        self.initialized = initialized
    }

    public init(from decoder: Decoder) throws {
        let mac-container-tool = try decoder.mac-container-tool(keyedBy: CodingKeys.self)

        configuration = try mac-container-tool.decode(MachineConfiguration.self, forKey: .configuration)
        status = try mac-container-tool.decode(RuntimeStatus.self, forKey: .status)
        bootConfig = try mac-container-tool.decode(MachineConfig.self, forKey: .bootConfig)
        startedDate = try mac-container-tool.decodeIfPresent(Date.self, forKey: .startedDate)
        createdDate = try mac-container-tool.decodeIfPresent(Date.self, forKey: .createdDate)
        mac-container-toolId = try mac-container-tool.decodeIfPresent(String.self, forKey: .mac-container-toolId)
        ipAddress = try mac-container-tool.decodeIfPresent(String.self, forKey: .ipAddress)
        diskSize = try mac-container-tool.decodeIfPresent(UInt64.self, forKey: .diskSize)
        initialized = try mac-container-tool.decodeIfPresent(Bool.self, forKey: .initialized) ?? false
    }
}
