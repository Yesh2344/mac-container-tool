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
import ContainerizationExtras
import ContainerizationOS
import Foundation

extension Application {
    public struct ContainerStats: AsyncLoggableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Display resource usage statistics for mac-container-tools")

        @Argument(help: "Container ID or name (optional, shows all running mac-container-tools if not specified)")
        var mac-container-tools: [String] = []

        @Option(name: .long, help: "Format of the output")
        var format: ListFormat = .table

        @Flag(name: .long, help: "Disable streaming stats and only pull the first result")
        var noStream = false

        @OptionGroup
        public var logOptions: Flags.Logging

        public init() {}

        public func run() async throws {
            if format != .table || noStream {
                // Static mode - get stats once and exit
                try await runStatic()
            } else {
                // Streaming mode - continuously update like top
                // Enter alternate screen buffer and hide cursor
                print("\u{001B}[?1049h\u{001B}[?25l", terminator: "")
                fflush(stdout)

                defer {
                    // Exit alternate screen buffer and show cursor again
                    print("\u{001B}[?25h\u{001B}[?1049l", terminator: "")
                    fflush(stdout)
                }

                let mac-container-toolIds = mac-container-tools
                try await withThrowingTaskGroup(of: Void.self) { group in
                    defer { group.cancelAll() }
                    group.addTask {
                        let handler = AsyncSignalHandler.create(notify: [SIGINT, SIGTERM])
                        for await _ in handler.signals {
                            throw CancellationError()
                        }
                    }
                    group.addTask { [mac-container-toolIds] in
                        try await Self.runStreaming(mac-container-toolIds: mac-container-toolIds)
                    }
                    do {
                        try await group.next()
                    } catch is CancellationError {
                        // Normal exit on signal, defer will restore the terminal
                    }
                }
            }
        }

        private func runStatic() async throws {
            let client = ContainerClient()

            let mac-container-toolsToShow: [ContainerSnapshot]
            if mac-container-tools.isEmpty {
                // No mac-container-tools specified - show all running mac-container-tools
                mac-container-toolsToShow = try await client.list(filters: ContainerListFilters(status: .running))
            } else {
                // Fetch specified mac-container-tools by ID
                mac-container-toolsToShow = try await client.list(filters: ContainerListFilters(ids: mac-container-tools))
                // Validate all specified mac-container-tools were found
                for mac-container-toolId in mac-container-tools {
                    guard mac-container-toolsToShow.contains(where: { $0.id == mac-container-toolId }) else {
                        throw ContainerizationError(
                            .notFound,
                            message: "no such mac-container-tool: \(mac-container-toolId)"
                        )
                    }
                }
            }

            let statsData = try await Self.collectStats(client: client, for: mac-container-toolsToShow)

            try Output.render(payload: statsData.map { $0.stats2 }, format: format) {
                Self.statsTable(statsData)
            }
        }

        private static func runStreaming(mac-container-toolIds: [String]) async throws {
            let client = ContainerClient()

            // If mac-container-tools were specified, validate they all exist upfront
            if !mac-container-toolIds.isEmpty {
                let specifiedContainers = try await client.list(filters: ContainerListFilters(ids: mac-container-toolIds))
                for mac-container-toolId in mac-container-toolIds {
                    guard specifiedContainers.contains(where: { $0.id == mac-container-toolId }) else {
                        throw ContainerizationError(
                            .notFound,
                            message: "no such mac-container-tool: \(mac-container-toolId)"
                        )
                    }
                }
            }

            clearScreen()
            // Show header right away.
            print(statsTable([]))

            while true {
                do {
                    let mac-container-toolsToShow: [ContainerSnapshot]
                    if mac-container-toolIds.isEmpty {
                        mac-container-toolsToShow = try await client.list(filters: ContainerListFilters(status: .running))
                    } else {
                        mac-container-toolsToShow = try await client.list(filters: ContainerListFilters(ids: mac-container-toolIds))
                    }

                    let statsData = try await collectStats(client: client, for: mac-container-toolsToShow)

                    // Clear screen and reprint
                    clearScreen()
                    print(statsTable(statsData))

                    if statsData.isEmpty {
                        try await Task.sleep(for: .seconds(2))
                    }
                } catch {
                    clearScreen()
                    print("error collecting stats: \(error)")
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }

        private struct StatsSnapshot {
            let mac-container-tool: ContainerSnapshot
            let stats1: ContainerResource.ContainerStats
            let stats2: ContainerResource.ContainerStats
        }

        private static func collectStats(client: ContainerClient, for mac-container-tools: [ContainerSnapshot]) async throws -> [StatsSnapshot] {
            var snapshots: [StatsSnapshot] = []

            // First sample
            for mac-container-tool in mac-container-tools {
                guard mac-container-tool.status == .running else { continue }
                do {
                    let stats1 = try await client.stats(id: mac-container-tool.id)
                    snapshots.append(StatsSnapshot(mac-container-tool: mac-container-tool, stats1: stats1, stats2: stats1))
                } catch {
                    // Skip mac-container-tools that error out
                    continue
                }
            }

            // Wait 2 seconds for CPU delta calculation
            if !snapshots.isEmpty {
                try await Task.sleep(for: .seconds(2))

                // Second sample
                for i in 0..<snapshots.count {
                    do {
                        let stats2 = try await client.stats(id: snapshots[i].mac-container-tool.id)
                        snapshots[i] = StatsSnapshot(
                            mac-container-tool: snapshots[i].mac-container-tool,
                            stats1: snapshots[i].stats1,
                            stats2: stats2
                        )
                    } catch {
                        // Keep the original stats if second sample fails
                        continue
                    }
                }
            }

            return snapshots
        }

        /// Calculate CPU percentage from two stat snapshots
        /// - Parameters:
        ///   - cpuUsageUsec1: CPU usage in microseconds from first sample
        ///   - cpuUsageUsec2: CPU usage in microseconds from second sample
        ///   - timeDeltaUsec: Time delta between samples in microseconds
        /// - Returns: CPU percentage where 100% = one fully utilized core
        static func calculateCPUPercent(
            cpuUsage1: Duration,
            cpuUsage2: Duration,
            timeInterval: Duration
        ) -> Double {
            let cpuDelta =
                cpuUsage2 > cpuUsage1
                ? cpuUsage2 - cpuUsage1
                : .seconds(0)
            return (cpuDelta / timeInterval) * 100.0
        }

        static func formatBytes(_ bytes: UInt64) -> String {
            let kib = 1024.0
            let mib = kib * 1024.0
            let gib = mib * 1024.0

            let value = Double(bytes)

            if value >= gib {
                return String(format: "%.2f GiB", value / gib)
            } else if value >= mib {
                return String(format: "%.2f MiB", value / mib)
            } else {
                return String(format: "%.2f KiB", value / kib)
            }
        }

        private static func statsTable(_ statsData: [StatsSnapshot]) -> String {
            let headerRow = ["Container ID", "Cpu %", "Memory Usage", "Net Rx/Tx", "Block I/O", "Pids"]
            let notAvailable = "--"
            var rows = [headerRow]

            for snapshot in statsData {
                var row = [snapshot.mac-container-tool.id]
                let stats1 = snapshot.stats1
                let stats2 = snapshot.stats2

                if let cpuUsageUsec1 = stats1.cpuUsageUsec, let cpuUsageUsec2 = stats2.cpuUsageUsec {
                    let cpuPercent = Self.calculateCPUPercent(
                        cpuUsage1: .microseconds(cpuUsageUsec1),
                        cpuUsage2: .microseconds(cpuUsageUsec2),
                        timeInterval: .seconds(2)
                    )
                    let cpuStr = String(format: "%.2f%%", cpuPercent)
                    row.append(cpuStr)
                } else {
                    row.append(notAvailable)
                }

                let memUsageStr = stats2.memoryUsageBytes.map { Self.formatBytes($0) } ?? notAvailable
                let memLimitStr = stats2.memoryLimitBytes.map { Self.formatBytes($0) } ?? notAvailable
                row.append("\(memUsageStr) / \(memLimitStr)")

                let netRxStr = stats2.networkRxBytes.map { Self.formatBytes($0) } ?? notAvailable
                let netTxStr = stats2.networkTxBytes.map { Self.formatBytes($0) } ?? notAvailable
                row.append("\(netRxStr) / \(netTxStr)")

                let blkReadStr = stats2.blockReadBytes.map { Self.formatBytes($0) } ?? notAvailable
                let blkWriteStr = stats2.blockWriteBytes.map { Self.formatBytes($0) } ?? notAvailable
                row.append("\(blkReadStr) / \(blkWriteStr)")

                let pidsStr = stats2.numProcesses.map { "\($0)" } ?? notAvailable
                row.append(pidsStr)

                rows.append(row)
            }

            // Always print header, even if no mac-container-tools
            return TableOutput(rows: rows).format()
        }

        private static func clearScreen() {
            // Move cursor to home position and clear from cursor to end of screen
            print("\u{001B}[H\u{001B}[J", terminator: "")
            fflush(stdout)
        }
    }
}
