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

import ContainerResource
import ContainerXPC
import Containerization
import ContainerizationError
import ContainerizationOCI
import Foundation

/// A client for interacting with the mac-container-tool API server.
///
/// This client holds a reusable XPC connection and provides methods for
/// mac-container-tool lifecycle operations. All methods that operate on a specific
/// mac-container-tool take an `id` parameter.
public struct ContainerClient: Sendable {
    private static let serviceIdentifier = "com.apple.mac-container-tool.apiserver"

    private let xpcClient: XPCClient

    /// Creates a new mac-container-tool client with a connection to the API server.
    public init() {
        self.xpcClient = XPCClient(service: Self.serviceIdentifier)
    }

    @discardableResult
    private func xpcSend(
        message: XPCMessage,
        timeout: Duration? = XPCClient.xpcRegistrationTimeout
    ) async throws -> XPCMessage {
        try await xpcClient.send(message, responseTimeout: timeout)
    }

    /// Create a new mac-container-tool with the given configuration.
    public func create(
        configuration: ContainerConfiguration,
        options: ContainerCreateOptions = .default,
        kernel: Kernel,
        initImage: String? = nil,
        runtimeData: Data? = nil
    ) async throws {
        do {
            let request = XPCMessage(route: .mac-container-toolCreate)

            let data = try JSONEncoder().encode(configuration)
            let kdata = try JSONEncoder().encode(kernel)
            let odata = try JSONEncoder().encode(options)
            request.set(key: .mac-container-toolConfig, value: data)
            request.set(key: .kernel, value: kdata)
            request.set(key: .mac-container-toolOptions, value: odata)

            if let initImage {
                request.set(key: .initImage, value: initImage)
            }

            if let runtimeData {
                request.set(key: .runtimeData, value: runtimeData)
            }

            try await xpcSend(message: request)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to create mac-container-tool",
                cause: error
            )
        }
    }

    /// List mac-container-tools matching the given filters.
    public func list(filters: ContainerListFilters = .all) async throws -> [ContainerSnapshot] {
        do {
            let request = XPCMessage(route: .mac-container-toolList)
            let filterData = try JSONEncoder().encode(filters)
            request.set(key: .listFilters, value: filterData)

            let response = try await xpcSend(
                message: request,
                timeout: .seconds(10)
            )
            let data = response.dataNoCopy(key: .mac-container-tools)
            guard let data else {
                return []
            }
            return try JSONDecoder().decode([ContainerSnapshot].self, from: data)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to list mac-container-tools",
                cause: error
            )
        }
    }

    /// Get the mac-container-tool for the provided id.
    public func get(id: String) async throws -> ContainerSnapshot {
        let mac-container-tools = try await list(filters: ContainerListFilters(ids: [id]))
        guard let mac-container-tool = mac-container-tools.first else {
            throw ContainerizationError(
                .notFound,
                message: "get failed: mac-container-tool \(id) not found"
            )
        }
        return mac-container-tool
    }

    /// Bootstrap the mac-container-tool's init process.
    public func bootstrap(
        id: String,
        stdio: [FileHandle?],
        dynamicEnv: [String: String] = [:]
    ) async throws -> ClientProcess {
        let request = XPCMessage(route: .mac-container-toolBootstrap)

        for (i, h) in stdio.enumerated() {
            let key: XPCKeys = try {
                switch i {
                case 0: .stdin
                case 1: .stdout
                case 2: .stderr
                default:
                    throw ContainerizationError(.invalidArgument, message: "invalid fd \(i)")
                }
            }()

            if let h {
                request.set(key: key, value: h)
            }
        }

        do {
            let dynamicEnv = try JSONEncoder().encode(dynamicEnv)
            request.set(key: .dynamicEnv, value: dynamicEnv)

            request.set(key: .id, value: id)
            try await xpcClient.send(request)
            return ClientProcessImpl(mac-container-toolId: id, xpcClient: xpcClient)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to bootstrap mac-container-tool",
                cause: error
            )
        }
    }

    /// Send a signal to the mac-container-tool.
    public func kill(id: String, signal: String) async throws {
        do {
            let request = XPCMessage(route: .mac-container-toolKill)
            request.set(key: .id, value: id)
            request.set(key: .processIdentifier, value: id)
            request.set(key: .signal, value: signal)

            try await xpcClient.send(request)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to kill mac-container-tool",
                cause: error
            )
        }
    }

    /// Stop the mac-container-tool and all processes currently executing inside.
    public func stop(id: String, opts: ContainerStopOptions = ContainerStopOptions.default) async throws {
        do {
            let request = XPCMessage(route: .mac-container-toolStop)
            let data = try JSONEncoder().encode(opts)
            request.set(key: .id, value: id)
            request.set(key: .stopOptions, value: data)

            try await xpcClient.send(request)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to stop mac-container-tool",
                cause: error
            )
        }
    }

    /// Delete the mac-container-tool along with any resources.
    public func delete(id: String, force: Bool = false) async throws {
        do {
            let request = XPCMessage(route: .mac-container-toolDelete)
            request.set(key: .id, value: id)
            request.set(key: .forceDelete, value: force)
            try await xpcClient.send(request)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to delete mac-container-tool",
                cause: error
            )
        }
    }

    /// Get the disk usage for a mac-container-tool.
    public func diskUsage(id: String) async throws -> UInt64 {
        let request = XPCMessage(route: .mac-container-toolDiskUsage)
        request.set(key: .id, value: id)
        let reply = try await xpcClient.send(request)

        let size = reply.uint64(key: .mac-container-toolSize)
        return size
    }

    /// Create a new process inside a running mac-container-tool.
    /// The process is in a created state and must still be started.
    public func createProcess(
        mac-container-toolId: String,
        processId: String,
        configuration: ProcessConfiguration,
        stdio: [FileHandle?]
    ) async throws -> ClientProcess {
        do {
            let request = XPCMessage(route: .mac-container-toolCreateProcess)
            request.set(key: .id, value: mac-container-toolId)
            request.set(key: .processIdentifier, value: processId)

            let data = try JSONEncoder().encode(configuration)
            request.set(key: .processConfig, value: data)

            for (i, h) in stdio.enumerated() {
                let key: XPCKeys = try {
                    switch i {
                    case 0: .stdin
                    case 1: .stdout
                    case 2: .stderr
                    default:
                        throw ContainerizationError(.invalidArgument, message: "invalid fd \(i)")
                    }
                }()

                if let h {
                    request.set(key: key, value: h)
                }
            }

            try await xpcClient.send(request)
            return ClientProcessImpl(mac-container-toolId: mac-container-toolId, processId: processId, xpcClient: xpcClient)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to create process in mac-container-tool",
                cause: error
            )
        }
    }

    /// Get the log file handles for a mac-container-tool.
    public func logs(id: String) async throws -> [FileHandle] {
        do {
            let request = XPCMessage(route: .mac-container-toolLogs)
            request.set(key: .id, value: id)

            let response = try await xpcClient.send(request)
            let fds = response.fileHandles(key: .logs)
            guard let fds else {
                throw ContainerizationError(
                    .internalError,
                    message: "no log fds returned"
                )
            }
            return fds
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to get logs for mac-container-tool \(id)",
                cause: error
            )
        }
    }

    /// Dial a port on the mac-container-tool via vsock.
    public func dial(id: String, port: UInt32) async throws -> FileHandle {
        let request = XPCMessage(route: .mac-container-toolDial)
        request.set(key: .id, value: id)
        request.set(key: .port, value: UInt64(port))

        let response: XPCMessage
        do {
            response = try await xpcClient.send(request)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to dial port \(port) on mac-container-tool",
                cause: error
            )
        }
        guard let fh = response.fileHandle(key: .fd) else {
            throw ContainerizationError(
                .internalError,
                message: "failed to get fd for vsock port \(port)"
            )
        }
        return fh
    }

    /// Copy a file or directory from the host into the mac-container-tool.
    public func copyIn(id: String, source: String, destination: String, mode: UInt32 = 0o644, createParents: Bool = true) async throws {
        let request = XPCMessage(route: .mac-container-toolCopyIn)
        request.set(key: .id, value: id)
        request.set(key: .sourcePath, value: source)
        request.set(key: .destinationPath, value: destination)
        request.set(key: .fileMode, value: UInt64(mode))
        request.set(key: .createParents, value: createParents)

        do {
            try await xpcSend(message: request, timeout: .seconds(300))
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to copy into mac-container-tool \(id)",
                cause: error
            )
        }
    }

    /// Copy a file or directory from the mac-container-tool to the host.
    public func copyOut(id: String, source: String, destination: String, createParents: Bool = true) async throws {
        let request = XPCMessage(route: .mac-container-toolCopyOut)
        request.set(key: .id, value: id)
        request.set(key: .sourcePath, value: source)
        request.set(key: .destinationPath, value: destination)
        request.set(key: .createParents, value: createParents)

        do {
            try await xpcSend(message: request, timeout: .seconds(300))
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to copy from mac-container-tool \(id)",
                cause: error
            )
        }
    }

    /// Get resource usage statistics for a mac-container-tool.
    public func stats(id: String) async throws -> ContainerStats {
        let request = XPCMessage(route: .mac-container-toolStats)
        request.set(key: .id, value: id)

        do {
            let response = try await xpcClient.send(request)
            guard let data = response.dataNoCopy(key: .statistics) else {
                throw ContainerizationError(
                    .internalError,
                    message: "no statistics data returned"
                )
            }
            return try JSONDecoder().decode(ContainerStats.self, from: data)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to get statistics for mac-container-tool \(id)",
                cause: error
            )
        }
    }

    public func export(id: String, archive: URL) async throws {
        let request = XPCMessage(route: .mac-container-toolExport)
        request.set(key: .id, value: id)
        request.set(key: .archive, value: archive.absolutePath())

        do {
            try await xpcClient.send(request)
        } catch {
            throw ContainerizationError(
                .internalError,
                message: "failed to export mac-container-tool",
                cause: error
            )
        }
    }
}
