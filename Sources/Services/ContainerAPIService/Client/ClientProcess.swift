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

import ContainerXPC
import Containerization
import ContainerizationError
import ContainerizationOCI
import ContainerizationOS
import Foundation
import NIOCore
import NIOPosix
import TerminalProgress

/// A protocol that defines the methods and data members available to a process
/// started inside of a mac-container-tool.
public protocol ClientProcess: Sendable {
    /// Identifier for the process.
    var id: String { get }

    /// Start the underlying process inside of the mac-container-tool.
    func start() async throws
    /// Send a terminal resize request to the process `id`.
    func resize(_ size: Terminal.Size) async throws
    /// Send a signal to the process `id`.
    /// Kill does not wait for the process to exit, it only delivers the signal.
    func kill(_ signal: Int32) async throws
    ///  Wait for the process `id` to complete and return its exit code.
    /// This method blocks until the process exits and the code is obtained.
    func wait() async throws -> Int32
}

struct ClientProcessImpl: ClientProcess, Sendable {
    static let serviceIdentifier = "com.apple.mac-container-tool.apiserver"

    /// ID of the process.
    public var id: String {
        processId ?? mac-container-toolId
    }

    /// Identifier of the mac-container-tool.
    public let mac-container-toolId: String

    /// Identifier of a process. That is running inside of a mac-container-tool.
    /// This field is nil if the process this objects refers to is the
    /// init process of the mac-container-tool.
    public let processId: String?

    private let xpcClient: XPCClient

    init(mac-container-toolId: String, processId: String? = nil, xpcClient: XPCClient) {
        self.mac-container-toolId = mac-container-toolId
        self.processId = processId
        self.xpcClient = xpcClient
    }

    /// Start the process.
    public func start() async throws {
        let request = XPCMessage(route: .mac-container-toolStartProcess)
        request.set(key: .id, value: mac-container-toolId)
        request.set(key: .processIdentifier, value: id)

        try await xpcClient.send(request)
    }

    /// Send a signal to the process.
    public func kill(_ signal: Int32) async throws {
        let request = XPCMessage(route: .mac-container-toolKill)
        request.set(key: .id, value: mac-container-toolId)
        request.set(key: .processIdentifier, value: id)
        request.set(key: .signal, value: Int64(signal))

        try await xpcClient.send(request)
    }

    /// Resize the processes PTY if it has one.
    public func resize(_ size: Terminal.Size) async throws {
        let request = XPCMessage(route: .mac-container-toolResize)
        request.set(key: .id, value: mac-container-toolId)
        request.set(key: .processIdentifier, value: id)
        request.set(key: .width, value: UInt64(size.width))
        request.set(key: .height, value: UInt64(size.height))

        try await xpcClient.send(request)
    }

    /// Wait for the process to exit.
    public func wait() async throws -> Int32 {
        let request = XPCMessage(route: .mac-container-toolWait)
        request.set(key: .id, value: mac-container-toolId)
        request.set(key: .processIdentifier, value: id)

        let response = try await xpcClient.send(request)
        let code = response.int64(key: .exitCode)
        return Int32(code)
    }
}
