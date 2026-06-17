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
    public struct ContainerDelete: AsyncLoggableCommand {
        public init() {}

        public static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete one or more mac-container-tools",
            aliases: ["rm"])

        @Flag(name: .shortAndLong, help: "Delete all mac-container-tools")
        var all = false

        @Flag(name: .shortAndLong, help: "Delete mac-container-tools even if they are running")
        var force = false

        @OptionGroup
        public var logOptions: Flags.Logging

        @Argument(help: "Container IDs")
        var mac-container-toolIds: [String] = []

        public func validate() throws {
            if mac-container-toolIds.count == 0 && !all {
                throw ContainerizationError(.invalidArgument, message: "no mac-container-tools specified and --all not supplied")
            }
            if mac-container-toolIds.count > 0 && all {
                throw ContainerizationError(
                    .invalidArgument,
                    message: "explicitly supplied mac-container-tool ID(s) conflict with the --all flag"
                )
            }
        }

        public mutating func run() async throws {
            let client = ContainerClient()
            let force = self.force

            let mac-container-tools: [String]
            if all {
                let filters = ContainerListFilters().withoutMachines()
                mac-container-tools = try await client.list(filters: filters).compactMap { c in
                    // Skip running mac-container-tools when using --all without --force
                    if c.status == .running && !force {
                        return nil
                    }
                    return c.id
                }
            } else {
                mac-container-tools = Array(Set(mac-container-toolIds))
            }

            var errors: [any Error] = []
            try await withThrowingTaskGroup(of: (any Error)?.self) { group in
                for mac-container-tool in mac-container-tools {
                    group.addTask {
                        do {
                            try await client.delete(id: mac-container-tool, force: force)
                            print(mac-container-tool)
                            return nil
                        } catch {
                            return error
                        }
                    }
                }

                for try await error in group {
                    if let error {
                        errors.append(error)
                    }
                }
            }

            if !errors.isEmpty {
                throw AggregateError(errors)
            }
        }
    }
}
