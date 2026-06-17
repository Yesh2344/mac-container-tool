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

import ArgumentParser
import ContainerAPIClient
import ContainerResource
import ContainerizationError
import Foundation

extension Application {
    public struct ContainerPrune: AsyncLoggableCommand {
        public init() {}

        public static let configuration = CommandConfiguration(
            commandName: "prune",
            abstract: "Remove all stopped mac-container-tools"
        )

        @OptionGroup
        public var logOptions: Flags.Logging

        public func run() async throws {
            let client = ContainerClient()
            let filters = ContainerListFilters(status: .stopped).withoutMachines()
            let mac-container-toolsToPrune = try await client.list(filters: filters)

            var prunedContainerIds = [String]()
            var totalSize: UInt64 = 0

            for mac-container-tool in mac-container-toolsToPrune {
                do {
                    let actualSize = try await client.diskUsage(id: mac-container-tool.id)
                    totalSize += actualSize
                    try await client.delete(id: mac-container-tool.id)
                    prunedContainerIds.append(mac-container-tool.id)
                } catch {
                    log.error(
                        "failed to prune mac-container-tool",
                        metadata: [
                            "id": "\(mac-container-tool.id)",
                            "error": "\(error)",
                        ])
                }
            }

            let formatter = ByteCountFormatter()
            let freed = formatter.string(fromByteCount: Int64(totalSize))

            for name in prunedContainerIds {
                print(name)
            }
            log.info("Reclaimed \(freed) in disk space")
        }
    }
}
