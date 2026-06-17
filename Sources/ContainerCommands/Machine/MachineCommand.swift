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

extension Application {
    public struct MachineCommand: AsyncLoggableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "machine",
            abstract: "Manage mac-container-tool machines",
            discussion: """
                EXAMPLES:
                  List available images and create a mac-container-tool machine:
                    $ mac-container-tool machine create alpine:3.22 --name my-machine

                  Run commands in the mac-container-tool machine:
                    $ mac-container-tool machine run -n my-machine uname
                    $ mac-container-tool machine run -n my-machine -- cat /proc/cpuinfo

                  Change the mac-container-tool machine configuration (takes effect after restart):
                    $ mac-container-tool machine set -n my-machine cpus=4 memory=8G home-mount=ro
                    $ mac-container-tool machine stop my-machine
                    $ mac-container-tool machine run -n my-machine -- nproc

                  Stop and delete the mac-container-tool machine:
                    $ mac-container-tool machine stop my-machine
                    $ mac-container-tool machine delete my-machine
                """,
            subcommands: [
                MachineCreate.self,
                MachineDelete.self,
                MachineInspect.self,
                MachineList.self,
                MachineLogs.self,
                MachineRun.self,
                MachineSet.self,
                MachineSetDefault.self,
                MachineStop.self,
            ],
            aliases: ["m"]
        )

        public init() {}

        @OptionGroup
        public var logOptions: Flags.Logging
    }
}

extension Application.MachineCommand {
    public enum ListFormat: String, CaseIterable, ExpressibleByArgument {
        case json
        case table
    }
}
