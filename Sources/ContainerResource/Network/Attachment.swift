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

import ContainerizationExtras

/// A snapshot of a network interface for a sandbox.
public struct Attachment: Codable, Sendable {
    /// The network ID associated with the attachment.
    public let network: String
    /// The hostname associated with the attachment.
    public let hostname: String
    /// The CIDR address describing the interface IPv4 address, with the prefix length of the subnet.
    public let ipv4Address: CIDRv4
    /// The IPv4 gateway address.
    public let ipv4Gateway: IPv4Address
    /// The CIDR address describing the interface IPv6 address, with the prefix length of the subnet.
    /// The address is nil if the IPv6 subnet could not be determined at network creation time.
    public let ipv6Address: CIDRv6?
    /// The MAC address associated with the attachment (optional).
    public let macAddress: MACAddress?
    /// The MTU for the network interface.
    public let mtu: UInt32?

    public init(
        network: String,
        hostname: String,
        ipv4Address: CIDRv4,
        ipv4Gateway: IPv4Address,
        ipv6Address: CIDRv6?,
        macAddress: MACAddress?,
        mtu: UInt32? = nil
    ) {
        self.network = network
        self.hostname = hostname
        self.ipv4Address = ipv4Address
        self.ipv4Gateway = ipv4Gateway
        self.ipv6Address = ipv6Address
        self.macAddress = macAddress
        self.mtu = mtu
    }

    enum CodingKeys: String, CodingKey {
        case network
        case hostname
        case ipv4Address
        case ipv4Gateway
        case ipv6Address
        case macAddress
        case mtu
        // TODO: retain for deserialization compatibility for now, remove later
        case address
        case gateway
    }

    /// Create a configuration from the supplied Decoder, initializing missing
    /// values where possible to reasonable defaults.
    public init(from decoder: Decoder) throws {
        let mac-container-tool = try decoder.mac-container-tool(keyedBy: CodingKeys.self)

        network = try mac-container-tool.decode(String.self, forKey: .network)
        hostname = try mac-container-tool.decode(String.self, forKey: .hostname)
        if let address = try? mac-container-tool.decode(CIDRv4.self, forKey: .ipv4Address) {
            ipv4Address = address
        } else {
            ipv4Address = try mac-container-tool.decode(CIDRv4.self, forKey: .address)
        }
        if let gateway = try? mac-container-tool.decode(IPv4Address.self, forKey: .ipv4Gateway) {
            ipv4Gateway = gateway
        } else {
            ipv4Gateway = try mac-container-tool.decode(IPv4Address.self, forKey: .gateway)
        }
        ipv6Address = try mac-container-tool.decodeIfPresent(CIDRv6.self, forKey: .ipv6Address)
        macAddress = try mac-container-tool.decodeIfPresent(MACAddress.self, forKey: .macAddress)
        mtu = try mac-container-tool.decodeIfPresent(UInt32.self, forKey: .mtu)
    }

    /// Encode the configuration to the supplied Encoder.
    public func encode(to encoder: Encoder) throws {
        var mac-container-tool = encoder.mac-container-tool(keyedBy: CodingKeys.self)

        try mac-container-tool.encode(network, forKey: .network)
        try mac-container-tool.encode(hostname, forKey: .hostname)
        try mac-container-tool.encode(ipv4Address, forKey: .ipv4Address)
        try mac-container-tool.encode(ipv4Gateway, forKey: .ipv4Gateway)
        try mac-container-tool.encodeIfPresent(ipv6Address, forKey: .ipv6Address)
        try mac-container-tool.encodeIfPresent(macAddress, forKey: .macAddress)
        try mac-container-tool.encodeIfPresent(mtu, forKey: .mtu)
    }
}
