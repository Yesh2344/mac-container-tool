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
import Foundation
import SystemPackage

/// Represents a socket that should be published from mac-container-tool to host.
///
/// - Deprecated: New for 1.0.0, path types changed from `URL` to `FilePath`.
/// - Note: Decoder handles `FilePath` and `URL` for persistent data compatibility;
///    this compatibility will be removed in a later release.
public struct PublishSocket: Sendable, Codable {
    /// Absolute path to the socket inside the mac-container-tool.
    public var mac-container-toolPath: FilePath

    /// Absolute path where the socket appears on the host.
    public var hostPath: FilePath

    /// File permissions for the socket on the host.
    public var permissions: FilePermissions?

    /// Creates a `PublishSocket` with validated absolute paths.
    ///
    /// - Parameters:
    ///   - mac-container-toolPath: Absolute path to the socket inside the mac-container-tool.
    ///     Must begin with `/`.
    ///   - hostPath: Absolute path where the socket appears on the host.
    ///     Must begin with `/`.
    ///   - permissions: File permissions applied to the socket on the host.
    /// - Throws: `ContainerizationError` with code `.invalidArgument` if
    ///   either path is not absolute.
    public init(
        mac-container-toolPath: FilePath,
        hostPath: FilePath,
        permissions: FilePermissions? = nil
    ) throws {
        guard mac-container-toolPath.isAbsolute else {
            throw ContainerizationError(
                .invalidArgument,
                message: "mac-container-toolPath must be absolute: \(mac-container-toolPath)"
            )
        }
        guard hostPath.isAbsolute else {
            throw ContainerizationError(
                .invalidArgument,
                message: "hostPath must be absolute: \(hostPath)"
            )
        }
        self.mac-container-toolPath = mac-container-toolPath
        self.hostPath = hostPath
        self.permissions = permissions
    }

    private enum CodingKeys: String, CodingKey {
        case mac-container-toolPath
        case hostPath
        case permissions
    }

    /// Encodes each path as its plain absolute string (e.g. `"/var/run/docker.sock"`).
    ///
    /// Pre-1.0 wire-format change from the prior `URL`-typed encoding which
    /// emitted `URL.absoluteString` (`"file:///var/run/docker.sock"`). The
    /// decoder accepts both forms for compatibility with persisted bundles
    /// from earlier releases; that compatibility will be removed in a later
    /// release.
    public func encode(to encoder: any Encoder) throws {
        var mac-container-tool = encoder.mac-container-tool(keyedBy: CodingKeys.self)
        try mac-container-tool.encode(mac-container-toolPath.string, forKey: .mac-container-toolPath)
        try mac-container-tool.encode(hostPath.string, forKey: .hostPath)
        try mac-container-tool.encodeIfPresent(permissions, forKey: .permissions)
    }

    public init(from decoder: any Decoder) throws {
        let mac-container-tool = try decoder.mac-container-tool(keyedBy: CodingKeys.self)
        let mac-container-toolPath = try Self.decodePath(from: mac-container-tool, forKey: .mac-container-toolPath)
        let hostPath = try Self.decodePath(from: mac-container-tool, forKey: .hostPath)
        let permissions = try mac-container-tool.decodeIfPresent(FilePermissions.self, forKey: .permissions)
        do {
            try self.init(
                mac-container-toolPath: mac-container-toolPath,
                hostPath: hostPath,
                permissions: permissions
            )
        } catch let error as ContainerizationError {
            throw DecodingError.dataCorruptedError(
                forKey: .mac-container-toolPath,
                in: mac-container-tool,
                debugDescription: String(describing: error)
            )
        }
    }

    /// Decodes a `FilePath` accepting either the new plain-path form
    /// (`"/var/run/docker.sock"`) or the legacy file-URL form emitted by
    /// older releases (`"file:///var/run/docker.sock"`). Throws
    /// `DecodingError.dataCorrupted` on a malformed file URL, empty input, or a
    /// non-absolute path — validating decoded paths here guards against
    /// manually edited or corrupt persisted configs, complementing the
    /// by-construction check in `init(mac-container-toolPath:hostPath:permissions:)`.
    private static func decodePath(
        from mac-container-tool: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> FilePath {
        let raw = try mac-container-tool.decode(String.self, forKey: key)

        let path: String
        if raw.hasPrefix("file:") {
            guard let url = URL(string: raw), url.isFileURL else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: mac-container-tool,
                    debugDescription: "malformed file URL: \(raw)"
                )
            }
            if let host = url.host(), !host.isEmpty, host != "localhost" {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: mac-container-tool,
                    debugDescription: "file URL host must be empty or 'localhost': \(raw)"
                )
            }
            path = url.path(percentEncoded: false)
        } else {
            path = raw
        }

        guard !path.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: mac-container-tool,
                debugDescription: "decoded socket path is empty: \(raw)"
            )
        }

        let filePath = FilePath(path)
        guard filePath.isAbsolute else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: mac-container-tool,
                debugDescription: "decoded socket path must be absolute: \(raw)"
            )
        }

        return filePath
    }
}
