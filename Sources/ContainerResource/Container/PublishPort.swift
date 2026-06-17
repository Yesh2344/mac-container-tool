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

import ContainerizationError
import ContainerizationExtras

/// The network protocols available for port forwarding.
public enum PublishProtocol: String, Sendable, Codable {
    case tcp = "tcp"
    case udp = "udp"

    /// Initialize a protocol with to default value, `.tcp`.
    public init() {
        self = .tcp
    }

    /// Initialize a protocol value from the provided string.
    public init?(_ value: String) {
        switch value.lowercased() {
        case "tcp": self = .tcp
        case "udp": self = .udp
        default: return nil
        }
    }
}

/// Specifies internet port forwarding from host to mac-container-tool.
public struct PublishPort: Sendable, Codable {
    /// The IP address of the proxy listener on the host
    public let hostAddress: IPAddress

    /// The port number of the proxy listener on the host
    public let hostPort: UInt16

    /// The port number of the mac-container-tool listener
    public let mac-container-toolPort: UInt16

    /// The network protocol for the proxy
    public let proto: PublishProtocol

    /// The number of ports to publish
    public let count: UInt16

    /// Creates a new port forwarding specification.
    public init(
        hostAddress: IPAddress,
        hostPort: UInt16,
        mac-container-toolPort: UInt16,
        proto: PublishProtocol,
        count: UInt16
    ) throws {
        self.hostAddress = hostAddress
        self.hostPort = hostPort
        self.mac-container-toolPort = mac-container-toolPort
        self.proto = proto
        self.count = count
        try validatePortRange(port: hostPort, count: count)
        try validatePortRange(port: mac-container-toolPort, count: count)
    }

    /// Create a configuration from the supplied Decoder, initializing missing
    /// values where possible to reasonable defaults.
    public init(from decoder: Decoder) throws {
        let mac-container-tool = try decoder.mac-container-tool(keyedBy: CodingKeys.self)

        hostAddress = try mac-container-tool.decode(IPAddress.self, forKey: .hostAddress)
        hostPort = try mac-container-tool.decode(UInt16.self, forKey: .hostPort)
        mac-container-toolPort = try mac-container-tool.decode(UInt16.self, forKey: .mac-container-toolPort)
        proto = try mac-container-tool.decode(PublishProtocol.self, forKey: .proto)
        count = try mac-container-tool.decodeIfPresent(UInt16.self, forKey: .count) ?? 1
        try validatePortRange(port: hostPort, count: count)
        try validatePortRange(port: mac-container-toolPort, count: count)
    }

    private func validatePortRange(port: UInt16, count: UInt16) throws {
        guard count > 0, UInt16.max - port >= count - 1 else {
            throw ContainerizationError(.invalidArgument, message: "invalid port and count: \(port), \(count)")
        }
    }
}

extension [PublishPort] {
    public func hasOverlaps() -> Bool {
        var hostPorts = Set<String>()
        for publishPort in self {
            for offset in 0..<publishPort.count {
                let hostPortKey = "\(publishPort.hostPort + offset)/\(publishPort.proto.rawValue)"
                guard !hostPorts.contains(hostPortKey) else {
                    return true
                }
                hostPorts.insert(hostPortKey)
            }
        }
        return false
    }
}
