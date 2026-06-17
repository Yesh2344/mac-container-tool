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

#if os(macOS)
import Foundation
import ContainerXPC

/// Keys for XPC fields.
public enum XPCKeys: String {
    /// Route key.
    case route
    /// Container array key.
    case mac-container-tools
    /// ID key.
    case id
    // ID for a process.
    case processIdentifier
    /// Container configuration key.
    case mac-container-toolConfig
    /// Container options key.
    case mac-container-toolOptions
    /// Opaque runtime-specific data.
    case runtimeData
    /// Vsock port number key.
    case port
    /// Exit code for a process
    case exitCode
    /// Exit timestamp for a process
    case exitedAt
    /// An event that occurred in a mac-container-tool
    case mac-container-toolEvent
    /// Error key.
    case error
    /// FD to a mac-container-tool resource key.
    case fd
    /// FDs pointing to mac-container-tool logs key.
    case logs
    /// Options for stopping a mac-container-tool key.
    case stopOptions
    /// Whether to force stop a mac-container-tool when deleting.
    case forceDelete
    /// Plugins
    case pluginName
    case plugins
    case plugin
    /// Archive path to export rootfs
    case archive
    /// Special-case environment variables recomputed on each mac-container-tool start
    case dynamicEnv

    /// Health check request.
    case ping
    case appRoot
    case installRoot
    case logRoot
    case apiServerVersion
    case apiServerCommit
    case apiServerBuild
    case apiServerAppName

    /// Process request keys.
    case signal
    case snapshot
    case stdin
    case stdout
    case stderr
    case status
    case width
    case height
    case processConfig

    /// Update progress
    case progressUpdateEndpoint
    case progressUpdateSetDescription
    case progressUpdateSetSubDescription
    case progressUpdateSetItemsName
    case progressUpdateAddTasks
    case progressUpdateSetTasks
    case progressUpdateAddTotalTasks
    case progressUpdateSetTotalTasks
    case progressUpdateAddItems
    case progressUpdateSetItems
    case progressUpdateAddTotalItems
    case progressUpdateSetTotalItems
    case progressUpdateAddSize
    case progressUpdateSetSize
    case progressUpdateAddTotalSize
    case progressUpdateSetTotalSize

    /// Network
    case networkId
    case networkConfig
    case networkResource
    case networkResources

    /// Kernel
    case kernel
    case kernelTarURL
    case kernelFilePath
    case systemPlatform
    case kernelForce

    /// Init image reference
    case initImage

    /// Volume
    case volume
    case volumes
    case volumeName
    case volumeSize
    case volumeDriver
    case volumeDriverOpts
    case volumeLabels
    case volumeReadonly
    case volumeContainerId

    /// Container statistics
    case statistics
    case mac-container-toolSize

    /// Container list filters
    case listFilters

    /// Disk usage
    case diskUsageStats

    /// Copy parameters
    case sourcePath
    case destinationPath
    case fileMode
    case createParents
}

public enum XPCRoute: String {
    case mac-container-toolList
    case mac-container-toolCreate
    case mac-container-toolBootstrap
    case mac-container-toolCreateProcess
    case mac-container-toolStartProcess
    case mac-container-toolWait
    case mac-container-toolDelete
    case mac-container-toolStop
    case mac-container-toolDial
    case mac-container-toolResize
    case mac-container-toolKill
    case mac-container-toolState
    case mac-container-toolLogs
    case mac-container-toolEvent
    case mac-container-toolStats
    case mac-container-toolDiskUsage
    case mac-container-toolCopyIn
    case mac-container-toolCopyOut
    case mac-container-toolExport

    case pluginLoad
    case pluginGet
    case pluginRestart
    case pluginUnload
    case pluginList

    case networkCreate
    case networkDelete
    case networkList

    case volumeCreate
    case volumeDelete
    case volumeList
    case volumeInspect

    case volumeDiskUsage
    case systemDiskUsage

    case ping

    case installKernel
    case getDefaultKernel
}

extension XPCMessage {
    public init(route: XPCRoute) {
        self.init(route: route.rawValue)
    }

    public func data(key: XPCKeys) -> Data? {
        data(key: key.rawValue)
    }

    public func dataNoCopy(key: XPCKeys) -> Data? {
        dataNoCopy(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: Data) {
        set(key: key.rawValue, value: value)
    }

    public func string(key: XPCKeys) -> String? {
        string(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: String) {
        set(key: key.rawValue, value: value)
    }

    public func bool(key: XPCKeys) -> Bool {
        bool(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: Bool) {
        set(key: key.rawValue, value: value)
    }

    public func uint64(key: XPCKeys) -> UInt64 {
        uint64(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: UInt64) {
        set(key: key.rawValue, value: value)
    }

    public func int64(key: XPCKeys) -> Int64 {
        int64(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: Int64) {
        set(key: key.rawValue, value: value)
    }

    public func int(key: XPCKeys) -> Int {
        Int(int64(key: key.rawValue))
    }

    public func set(key: XPCKeys, value: Int) {
        set(key: key.rawValue, value: Int64(value))
    }

    public func date(key: XPCKeys) -> Date {
        date(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: Date) {
        set(key: key.rawValue, value: value)
    }

    public func fileHandle(key: XPCKeys) -> FileHandle? {
        fileHandle(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: FileHandle) {
        set(key: key.rawValue, value: value)
    }

    public func fileHandles(key: XPCKeys) -> [FileHandle]? {
        fileHandles(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: [FileHandle]) throws {
        try set(key: key.rawValue, value: value)
    }

    public func endpoint(key: XPCKeys) -> xpc_endpoint_t? {
        endpoint(key: key.rawValue)
    }

    public func set(key: XPCKeys, value: xpc_endpoint_t) {
        set(key: key.rawValue, value: value)
    }
}

#endif
