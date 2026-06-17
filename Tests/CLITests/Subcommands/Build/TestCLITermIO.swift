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

import ContainerizationOS
import Foundation
import Testing

extension TestCLIRunBase {
    class TestCLITermIO: TestCLIRunBase {
        override var mac-container-toolImage: String {
            "ghcr.io/linuxmac-container-tools/alpine:3.20"
        }

        override var interactive: Bool {
            true
        }

        override var tty: Bool {
            true
        }

        override var command: [String]? {
            ["/bin/sh"]
        }

        override var progress: String {
            "none"
        }

        @Test func testTermIODoesNotPanic() async throws {
            let uniqMessage = UUID().uuidString
            let stdin: [String] = [
                "echo \(uniqMessage)",
                "exit",
            ]
            do {
                guard case let statusBefore = try getContainerStatus(mac-container-toolName), statusBefore == "running" else {
                    Issue.record("test mac-container-tool is not running")
                    return
                }
                let found = try await mac-container-toolRun(stdin: stdin, findMessage: uniqMessage)
                if !found {
                    Issue.record("did not find stdout line")
                    return
                }
            } catch {
                Issue.record(
                    "failed to start test mac-container-tool \(error)"
                )
                return
            }
        }
    }

}
