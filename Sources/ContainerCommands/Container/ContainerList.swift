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
import ContainerizationExtras
import Foundation
import SwiftProtobuf

extension Application {
    public struct ContainerList: AsyncLoggableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List running mac-container-tools",
            aliases: ["ls"])

        @Flag(name: .shortAndLong, help: "Include mac-container-tools that are not running")
        var all = false

        @Option(name: .long, help: "Format of the output")
        var format: ListFormat = .table

        @Flag(name: .shortAndLong, help: "Only output the mac-container-tool ID")
        var quiet = false

        @OptionGroup
        public var logOptions: Flags.Logging

        public init() {}

        public func run() async throws {
            let client = ContainerClient()

            let filters = ContainerListFilters(status: self.all ? nil : .running).withoutMachines()
            let mac-container-tools = try await client.list(filters: filters)
            let items = mac-container-tools.map { ManagedContainer($0) }
            try Output.render(payload: items, display: items, format: format, quiet: quiet)
        }
    }
}
