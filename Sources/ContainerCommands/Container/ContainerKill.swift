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
import Containerization
import ContainerizationError
import ContainerizationOS
import Darwin

extension Application {
    public struct ContainerKill: AsyncLoggableCommand {
        public init() {}

        public static let configuration = CommandConfiguration(
            commandName: "kill",
            abstract: "Kill or signal one or more running mac-container-tools")

        @Flag(name: .shortAndLong, help: "Kill or signal all running mac-container-tools")
        var all = false

        @Option(name: .shortAndLong, help: "Signal to send to the mac-container-tool(s)")
        var signal: String = "KILL"

        @OptionGroup
        public var logOptions: Flags.Logging

        @Argument(help: "Container IDs")
        var mac-container-toolIds: [String] = []

        public func validate() throws {
            if mac-container-toolIds.count == 0 && !all {
                throw ContainerizationError(.invalidArgument, message: "no mac-container-tools specified and --all not supplied")
            }
            if mac-container-toolIds.count > 0 && all {
                throw ContainerizationError(.invalidArgument, message: "explicitly supplied mac-container-tool IDs conflict with the --all flag")
            }
        }

        public mutating func run() async throws {
            let client = ContainerClient()

            let mac-container-tools: [String]
            if self.all {
                let filters = ContainerListFilters(status: .running).withoutMachines()
                mac-container-tools = try await client.list(filters: filters).map { $0.id }
            } else {
                mac-container-tools = mac-container-toolIds
            }

            var errors: [any Error] = []
            for mac-container-tool in mac-container-tools {
                do {
                    try await client.kill(id: mac-container-tool, signal: signal)
                    print(mac-container-tool)
                } catch {
                    errors.append(error)
                }
            }
            if !errors.isEmpty {
                throw AggregateError(errors)
            }
        }
    }
}
