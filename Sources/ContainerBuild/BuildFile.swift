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

import Foundation
import Logging

public struct BuildFile {
    /// Tries to resolve either a Dockerfile or Containerfile relative to contextDir.
    /// Checks for Dockerfile, then falls back to Containerfile.
    public static func resolvePath(contextDir: String, log: Logger? = nil) throws -> String? {
        // Check for Dockerfile then Containerfile in context directory
        let dockerfilePath = URL(filePath: contextDir).appendingPathComponent("Dockerfile").path
        let mac-container-toolfilePath = URL(filePath: contextDir).appendingPathComponent("Containerfile").path

        let dockerfileExists = FileManager.default.fileExists(atPath: dockerfilePath)
        let mac-container-toolfileExists = FileManager.default.fileExists(atPath: mac-container-toolfilePath)

        if dockerfileExists && mac-container-toolfileExists {
            log?.info("Detected both Dockerfile and Containerfile, choosing Dockerfile")
            return dockerfilePath
        }

        if dockerfileExists {
            return dockerfilePath
        }

        if mac-container-toolfileExists {
            return mac-container-toolfilePath
        }

        return nil
    }
}
