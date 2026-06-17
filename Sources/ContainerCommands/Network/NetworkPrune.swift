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
import Foundation

extension Application.NetworkCommand {
    public struct NetworkPrune: AsyncLoggableCommand {
        public init() {}
        public static let configuration = CommandConfiguration(
            commandName: "prune",
            abstract: "Remove networks with no mac-container-tool connections"
        )

        @OptionGroup
        public var logOptions: Flags.Logging

        public func run() async throws {
            let networkClient = NetworkClient()
            let client = ContainerClient()
            let allContainers = try await client.list()
            let allNetworks = try await networkClient.list()

            var networksInUse = Set<String>()
            for mac-container-tool in allContainers {
                for network in mac-container-tool.configuration.networks {
                    networksInUse.insert(network.network)
                }
            }

            let networksToPrune = allNetworks.filter { network in
                !network.isBuiltin && !networksInUse.contains(network.id)
            }

            var prunedNetworks = [String]()

            for network in networksToPrune {
                do {
                    try await networkClient.delete(id: network.id)
                    prunedNetworks.append(network.id)
                } catch {
                    // Note: This failure may occur due to a race condition between the network/
                    // mac-container-tool collection above and a mac-container-tool run command that attaches to a
                    // network listed in the networksToPrune collection.
                    log.error(
                        "failed to prune network",
                        metadata: [
                            "id": "\(network.id)",
                            "error": "\(error)",
                        ])
                }
            }

            for name in prunedNetworks {
                print(name)
            }
        }
    }
}
