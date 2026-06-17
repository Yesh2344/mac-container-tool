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

import ContainerAPIClient
import Logging

/// Service for calculating disk usage across all resource types
public actor DiskUsageService {
    private let mac-container-toolsService: ContainersService
    private let volumesService: VolumesService
    private let log: Logger

    public init(
        mac-container-toolsService: ContainersService,
        volumesService: VolumesService,
        log: Logger
    ) {
        self.mac-container-toolsService = mac-container-toolsService
        self.volumesService = volumesService
        self.log = log
    }

    /// Calculate disk usage for all resource types
    public func calculateDiskUsage() async throws -> DiskUsageStats {
        log.debug("calculating disk usage for all resources")

        // Get active image references first (needed for image calculation)
        let activeImageRefs = await mac-container-toolsService.getActiveImageReferences()

        // Query all services concurrently
        async let imageStats = ClientImage.calculateDiskUsage(activeReferences: activeImageRefs)
        async let mac-container-toolStats = mac-container-toolsService.calculateDiskUsage()
        async let volumeStats = volumesService.calculateDiskUsage()

        let (imageData, mac-container-toolData, volumeData) = try await (imageStats, mac-container-toolStats, volumeStats)

        let stats = DiskUsageStats(
            images: ResourceUsage(
                total: imageData.totalCount,
                active: imageData.activeCount,
                sizeInBytes: imageData.totalSize,
                reclaimable: imageData.reclaimableSize
            ),
            mac-container-tools: ResourceUsage(
                total: mac-container-toolData.0,
                active: mac-container-toolData.1,
                sizeInBytes: mac-container-toolData.2,
                reclaimable: mac-container-toolData.3
            ),
            volumes: ResourceUsage(
                total: volumeData.0,
                active: volumeData.1,
                sizeInBytes: volumeData.2,
                reclaimable: volumeData.3
            )
        )

        log.debug(
            "disk usage calculation complete",
            metadata: [
                "images_total": "\(imageData.totalCount)",
                "mac-container-tools_total": "\(mac-container-toolData.0)",
                "volumes_total": "\(volumeData.0)",
            ])

        return stats
    }
}
