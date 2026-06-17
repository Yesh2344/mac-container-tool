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

public enum MachineRoutes: String {
    /// Create a mac-container-tool machine.
    case createMachine
    /// Delete a mac-container-tool machine.
    case deleteMachine
    /// List mac-container-tool machines.
    case listMachine
    /// Get the default mac-container-tool machine.
    case getDefault
    /// Set the default mac-container-tool machine.
    case setDefault
    /// Boot a mac-container-tool machine.
    case bootMachine
    /// Stop a mac-container-tool machine.
    case stopMachine
    /// Inspect a mac-container-tool machine.
    case inspectMachine
    /// Set boot-time config for a mac-container-tool machine.
    case setConfig
    /// Fetch logs of a mac-container-tool machine.
    case logsMachine
}
