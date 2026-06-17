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
import Foundation
import Logging

extension Application {
    public struct ContainerStop: AsyncLoggableCommand {
        public init() {}

        public static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop one or more running mac-container-tools")

        @Flag(name: .shortAndLong, help: "Stop all running mac-container-tools")
        var all = false

        @Option(name: .shortAndLong, help: "Signal to send to the mac-container-tools")
        var signal: String?

        @Option(name: .shortAndLong, help: "Seconds to wait before killing the mac-container-tools")
        var time: Int32 = 5

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
                    .invalidArgument, message: "explicitly supplied mac-container-tool IDs conflict with the --all flag")
            }
        }

        public mutating func run() async throws {
            let client = ContainerClient()

            let mac-container-tools: [String]
            if self.all {
                let filters = ContainerListFilters().withoutMachines()
                mac-container-tools = try await client.list(filters: filters).map { $0.id }
            } else {
                mac-container-tools = mac-container-toolIds
            }

            let opts = ContainerStopOptions(
                timeoutInSeconds: self.time,
                signal: self.signal
            )
            try await Self.stopContainers(
                client: client,
                mac-container-tools: mac-container-tools,
                stopOptions: opts
            )
        }

        static func stopContainers(client: ContainerClient, mac-container-tools: [String], stopOptions: ContainerStopOptions) async throws {
            var errors: [any Error] = []
            await withTaskGroup(of: (any Error)?.self) { group in
                for mac-container-tool in mac-container-tools {
                    group.addTask {
                        do {
                            try await client.stop(id: mac-container-tool, opts: stopOptions)
                            print(mac-container-tool)
                            return nil
                        } catch {
                            return error
                        }
                    }
                }

                for await error in group {
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
