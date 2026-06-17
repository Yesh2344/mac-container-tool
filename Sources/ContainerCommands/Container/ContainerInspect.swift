//===----------------------------------------------------------------------===//
// Copyright © 2025-2026 Apple Inc. and the mac-container-tool project authors.
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

import ArgumentParser
import ContainerAPIClient
import ContainerResource
import ContainerizationError
import Foundation

extension Application {
    public struct ContainerInspect: AsyncLoggableCommand {
        public init() {}

        public static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Display information about one or more mac-container-tools")

        @OptionGroup
        public var logOptions: Flags.Logging

        @Argument(help: "Container IDs to inspect")
        var mac-container-toolIds: [String]

        public func run() async throws {
            let client = ContainerClient()
            let uniqueIds = Set(mac-container-toolIds)
            let mac-container-tools = try await client.list().filter {
                uniqueIds.contains($0.id)
            }

            if mac-container-tools.count != uniqueIds.count {
                let found = Set(mac-container-tools.map { $0.id })
                let missing = uniqueIds.subtracting(found).sorted()
                throw ContainerizationError(
                    .notFound,
                    message: "mac-container-tool not found: \(missing.joined(separator: ", "))"
                )
            }

            try Output.emit(Output.renderJSON(mac-container-tools.map { ManagedContainer($0) }, options: .pretty))
        }
    }
}
