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

public struct ContainerConfiguration: Sendable, Codable {
    /// Identifier for the mac-container-tool.
    public var id: String
    /// Image used to create the mac-container-tool.
    public var image: ImageDescription
    /// External mounts to add to the mac-container-tool.
    public var mounts: [Filesystem] = []
    /// Ports to publish from mac-container-tool to host.
    public var publishedPorts: [PublishPort] = []
    /// Sockets to publish from mac-container-tool to host.
    public var publishedSockets: [PublishSocket] = []
    /// Key/Value labels for the mac-container-tool.
    public var labels: [String: String] = [:]
    /// System controls for the mac-container-tool.
    public var sysctls: [String: String] = [:]
    /// The networks the mac-container-tool will be added to.
    public var networks: [AttachmentConfiguration] = []
    /// The DNS configuration for the mac-container-tool.
    public var dns: DNSConfiguration? = nil
    /// Whether to enable rosetta x86-64 translation for the mac-container-tool.
    public var rosetta: Bool = false
    /// Initial or main process of the mac-container-tool.
    public var initProcess: ProcessConfiguration
    /// Platform for the mac-container-tool.
    public var platform: ContainerizationOCI.Platform = .current
    /// Resource values for the mac-container-tool.
    public var resources: Resources = .init()
    /// Name of the runtime that supports the mac-container-tool.
    public var runtimeHandler: String = "mac-container-tool-runtime-linux"
    /// Configure exposing virtualization support in the mac-container-tool.
    public var virtualization: Bool = false
    /// Enable SSH agent socket forwarding from host to mac-container-tool.
    public var ssh: Bool = false
    /// Whether to mount the rootfs as read-only.
    public var readOnly: Bool = false
    /// Whether to use a minimal init process inside the mac-container-tool.
    public var useInit: Bool = false
    /// Linux capabilities to add (normalized CAP_* strings, or "ALL").
    public var capAdd: [String] = []
    /// Linux capabilities to drop (normalized CAP_* strings, or "ALL").
    public var capDrop: [String] = []
    /// Size of /dev/shm in bytes. When nil, the default size is used.
    public var shmSize: UInt64?
    /// Signal to send to the mac-container-tool process on stop (from image config).
    public var stopSignal: String?
    /// The time at which the mac-container-tool was created.
    public var creationDate: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case image
        case mounts
        case publishedPorts
        case publishedSockets
        case labels
        case sysctls
        case networks
        case dns
        case rosetta
        case initProcess
        case platform
        case resources
        case runtimeHandler
        case virtualization
        case ssh
        case readOnly
        case useInit
        case capAdd
        case capDrop
        case shmSize
        case stopSignal
        case creationDate
    }

    /// Create a configuration from the supplied Decoder, initializing missing
    /// values where possible to reasonable defaults.
    public init(from decoder: Decoder) throws {
        let mac-container-tool = try decoder.mac-container-tool(keyedBy: CodingKeys.self)

        id = try mac-container-tool.decode(String.self, forKey: .id)
        image = try mac-container-tool.decode(ImageDescription.self, forKey: .image)
        mounts = try mac-container-tool.decodeIfPresent([Filesystem].self, forKey: .mounts) ?? []
        publishedPorts = try mac-container-tool.decodeIfPresent([PublishPort].self, forKey: .publishedPorts) ?? []
        publishedSockets = try mac-container-tool.decodeIfPresent([PublishSocket].self, forKey: .publishedSockets) ?? []
        labels = try mac-container-tool.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        sysctls = try mac-container-tool.decodeIfPresent([String: String].self, forKey: .sysctls) ?? [:]

        if mac-container-tool.contains(.networks) {
            networks = try mac-container-tool.decode([AttachmentConfiguration].self, forKey: .networks)
        } else {
            networks = []
        }

        dns = try mac-container-tool.decodeIfPresent(DNSConfiguration.self, forKey: .dns)
        rosetta = try mac-container-tool.decodeIfPresent(Bool.self, forKey: .rosetta) ?? false
        initProcess = try mac-container-tool.decode(ProcessConfiguration.self, forKey: .initProcess)
        platform = try mac-container-tool.decodeIfPresent(ContainerizationOCI.Platform.self, forKey: .platform) ?? .current
        resources = try mac-container-tool.decodeIfPresent(Resources.self, forKey: .resources) ?? .init()
        runtimeHandler = try mac-container-tool.decodeIfPresent(String.self, forKey: .runtimeHandler) ?? "mac-container-tool-runtime-linux"
        virtualization = try mac-container-tool.decodeIfPresent(Bool.self, forKey: .virtualization) ?? false
        ssh = try mac-container-tool.decodeIfPresent(Bool.self, forKey: .ssh) ?? false
        readOnly = try mac-container-tool.decodeIfPresent(Bool.self, forKey: .readOnly) ?? false
        useInit = try mac-container-tool.decodeIfPresent(Bool.self, forKey: .useInit) ?? false
        capAdd = try mac-container-tool.decodeIfPresent([String].self, forKey: .capAdd) ?? []
        capDrop = try mac-container-tool.decodeIfPresent([String].self, forKey: .capDrop) ?? []
        shmSize = try mac-container-tool.decodeIfPresent(UInt64.self, forKey: .shmSize)
        stopSignal = try mac-container-tool.decodeIfPresent(String.self, forKey: .stopSignal)
        creationDate = try mac-container-tool.decodeIfPresent(Date.self, forKey: .creationDate) ?? Date(timeIntervalSince1970: 0)
    }

    public struct DNSConfiguration: Sendable, Codable {
        public static let defaultNameservers = ["1.1.1.1"]

        public let nameservers: [String]
        public let domain: String?
        public let searchDomains: [String]
        public let options: [String]

        public init(
            nameservers: [String] = defaultNameservers,
            domain: String? = nil,
            searchDomains: [String] = [],
            options: [String] = []
        ) {
            self.nameservers = nameservers
            self.domain = domain
            self.searchDomains = searchDomains
            self.options = options
        }
    }

    /// Resources like cpu, memory, and storage quota.
    public struct Resources: Sendable, Codable {
        /// Number of CPU cores allocated.
        public var cpus: Int = 4
        /// Memory in bytes allocated.
        public var memoryInBytes: UInt64 = 1024.mib()
        /// Storage quota/size in bytes.
        public var storage: UInt64?
        /// Additional CPU cores allocated for VM overhead (guest agent, etc).
        public var cpuOverhead: Int = 1

        public init() {}

        public init(from decoder: any Decoder) throws {
            let c = try decoder.mac-container-tool(keyedBy: CodingKeys.self)
            self.cpus = try c.decodeIfPresent(Int.self, forKey: .cpus) ?? 4
            self.memoryInBytes = try c.decodeIfPresent(UInt64.self, forKey: .memoryInBytes) ?? 1024.mib()
            self.storage = try c.decodeIfPresent(UInt64.self, forKey: .storage)
            self.cpuOverhead = try c.decodeIfPresent(Int.self, forKey: .cpuOverhead) ?? 1
        }
    }

    public init(
        id: String,
        image: ImageDescription,
        process: ProcessConfiguration
    ) {
        self.id = id
        self.image = image
        self.initProcess = process
    }
}
