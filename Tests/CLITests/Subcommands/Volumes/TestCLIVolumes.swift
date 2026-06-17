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

import ContainerAPIClient
import Foundation
import Testing

@Suite(.serialSuites, .serialized)
class TestCLIVolumes: CLITest {

    func doVolumeCreate(name: String) throws {
        let (_, _, error, status) = try run(arguments: ["volume", "create", name])
        if status != 0 {
            throw CLIError.executionFailed("volume create failed: \(error)")
        }
    }

    func doVolumeDelete(name: String) throws {
        let (_, _, error, status) = try run(arguments: ["volume", "rm", name])
        if status != 0 {
            throw CLIError.executionFailed("volume delete failed: \(error)")
        }
    }

    func doVolumeDeleteIfExists(name: String) {
        let (_, _, _, _) = (try? run(arguments: ["volume", "rm", name])) ?? (nil, "", "", 1)
    }

    func doRemoveIfExists(name: String, force: Bool = false) {
        var args = ["delete"]
        if force {
            args.append("--force")
        }
        args.append(name)
        let (_, _, _, _) = (try? run(arguments: args)) ?? (nil, "", "", 1)
    }

    func doesVolumeDeleteFail(name: String) throws -> Bool {
        let (_, _, _, status) = try run(arguments: ["volume", "rm", name])
        return status != 0
    }

    private func getTestName() -> String {
        Test.current!.name.trimmingCharacters(in: ["(", ")"]).lowercased()
    }

    @Test func testVolumeDataPersistenceAcrossContainers() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"
        let mac-container-tool1Name = "\(testName)_c1"
        let mac-container-tool2Name = "\(testName)_c2"
        let testData = "persistent-data-test"
        let testFile = "/data/test.txt"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName)
        doRemoveIfExists(name: mac-container-tool1Name, force: true)
        doRemoveIfExists(name: mac-container-tool2Name, force: true)

        defer {
            // Clean up mac-container-tools and volume
            try? doStop(name: mac-container-tool1Name)
            doRemoveIfExists(name: mac-container-tool1Name, force: true)
            try? doStop(name: mac-container-tool2Name)
            doRemoveIfExists(name: mac-container-tool2Name, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        // Create volume
        try doVolumeCreate(name: volumeName)

        // Run first mac-container-tool with volume, write data, then stop
        try doLongRun(name: mac-container-tool1Name, args: ["-v", "\(volumeName):/data"])
        try waitForContainerRunning(mac-container-tool1Name)

        // Write test data to the volume
        _ = try doExec(name: mac-container-tool1Name, cmd: ["sh", "-c", "echo '\(testData)' > \(testFile)"])

        // Stop first mac-container-tool
        try doStop(name: mac-container-tool1Name)

        // Run second mac-container-tool with same volume
        try doLongRun(name: mac-container-tool2Name, args: ["-v", "\(volumeName):/data"])
        try waitForContainerRunning(mac-container-tool2Name)

        // Verify data persisted
        var output = try doExec(name: mac-container-tool2Name, cmd: ["cat", testFile])
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(output == testData, "expected persisted data '\(testData)', instead got '\(output)'")

        try doStop(name: mac-container-tool2Name)
        try doVolumeDelete(name: volumeName)
    }

    @Test func testVolumeSharedAccessConflict() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"
        let mac-container-tool1Name = "\(testName)_c1"
        let mac-container-tool2Name = "\(testName)_c2"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName)
        doRemoveIfExists(name: mac-container-tool1Name, force: true)
        doRemoveIfExists(name: mac-container-tool2Name, force: true)

        defer {
            // Clean up mac-container-tools and volume
            try? doStop(name: mac-container-tool1Name)
            doRemoveIfExists(name: mac-container-tool1Name, force: true)
            try? doStop(name: mac-container-tool2Name)
            doRemoveIfExists(name: mac-container-tool2Name, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        // Create volume
        try doVolumeCreate(name: volumeName)

        // Run first mac-container-tool with volume
        try doLongRun(name: mac-container-tool1Name, args: ["-v", "\(volumeName):/data"])
        try waitForContainerRunning(mac-container-tool1Name)

        // Try to run second mac-container-tool with same volume - should fail
        let (_, _, _, status) = try run(arguments: ["run", "--name", mac-container-tool2Name, "-v", "\(volumeName):/data", alpine] + defaultContainerArgs)

        #expect(status != 0, "second mac-container-tool should fail when trying to use volume already in use")

        // Clean up
        try doStop(name: mac-container-tool1Name)
        doRemoveIfExists(name: mac-container-tool1Name, force: true)
        doVolumeDeleteIfExists(name: volumeName)
    }

    @Test func testVolumeDeleteProtectionWhileInUse() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"
        let mac-container-toolName = "\(testName)_c1"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName)
        doRemoveIfExists(name: mac-container-toolName, force: true)

        defer {
            // Clean up mac-container-tool and volume
            try? doStop(name: mac-container-toolName)
            doRemoveIfExists(name: mac-container-toolName, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        // Create volume
        try doVolumeCreate(name: volumeName)

        // Run mac-container-tool with volume
        try doLongRun(name: mac-container-toolName, args: ["-v", "\(volumeName):/data"])
        try waitForContainerRunning(mac-container-toolName)

        // Try to delete volume while mac-container-tool is running - should fail
        let deleteFailedWhileInUse = try doesVolumeDeleteFail(name: volumeName)
        #expect(deleteFailedWhileInUse, "volume delete should fail while volume is in use")

        // Stop mac-container-tool
        try doStop(name: mac-container-toolName)
        doRemoveIfExists(name: mac-container-toolName, force: true)

        // Now volume delete should succeed
        try doVolumeDelete(name: volumeName)
    }

    @Test func testVolumeDeleteProtectionWithCreatedContainer() async throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"
        let mac-container-toolName = "\(testName)_c1"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName)
        doRemoveIfExists(name: mac-container-toolName, force: true)

        defer {
            // Clean up mac-container-tool and volume
            try? doStop(name: mac-container-toolName)
            doRemoveIfExists(name: mac-container-toolName, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        // Create volume
        try doVolumeCreate(name: volumeName)

        // Create (but don't start) mac-container-tool with volume
        try doCreate(name: mac-container-toolName, image: alpine, volumes: ["\(volumeName):/mnt/data"])

        // Give some time for mac-container-tool to be fully registered
        try await Task.sleep(for: .seconds(1))

        // Try to delete volume while mac-container-tool is created - should fail
        let deleteFailedWhileInUse = try doesVolumeDeleteFail(name: volumeName)
        #expect(deleteFailedWhileInUse, "volume delete should fail when volume is used by created mac-container-tool")

        // Remove the mac-container-tool
        doRemoveIfExists(name: mac-container-toolName, force: true)

        // Now volume delete should succeed
        doVolumeDeleteIfExists(name: volumeName)
    }

    @Test func testVolumeBasicOperations() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName)

        defer {
            doVolumeDeleteIfExists(name: volumeName)
        }

        // Create volume
        try doVolumeCreate(name: volumeName)

        // List volumes and verify it exists
        let (_, output, error, status) = try run(arguments: ["volume", "list", "--quiet"])
        if status != 0 {
            throw CLIError.executionFailed("volume list failed: \(error)")
        }

        let volumes = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        #expect(volumes.contains(volumeName), "created volume should appear in list")

        // Inspect volume
        let (_, inspectOutput, inspectError, inspectStatus) = try run(arguments: ["volume", "inspect", volumeName])
        if inspectStatus != 0 {
            throw CLIError.executionFailed("volume inspect failed: \(inspectError)")
        }

        #expect(inspectOutput.contains(volumeName), "volume inspect should contain volume name")
        #expect(inspectOutput.contains("\"creationDate\""), "inspect JSON should use creationDate key")
        #expect(!inspectOutput.contains("\"createdAt\""), "inspect JSON must not use deprecated createdAt key")

        // Delete volume
        try doVolumeDelete(name: volumeName)
    }

    @Test func testImplicitNamedVolumeCreation() throws {
        let testName = getTestName()
        let mac-container-toolName = "\(testName)_c1"
        let volumeName = "\(testName)_autovolume"

        defer {
            doRemoveIfExists(name: mac-container-toolName, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        // Verify volume doesn't exist yet
        let (_, listOutput, _, _) = try run(arguments: ["volume", "list", "--quiet"])
        let volumeExistsBefore = listOutput.contains(volumeName)
        #expect(!volumeExistsBefore, "volume should not exist initially")

        // Run mac-container-tool with non-existent named volume - should auto-create
        let (_, output, _, status) = try run(arguments: [
            "run",
            "--name",
            mac-container-toolName,
            "-v", "\(volumeName):/data",
            alpine,
            "echo", "test",
        ])

        // Should succeed and create volume automatically
        #expect(status == 0, "should succeed and auto-create named volume")
        #expect(output.contains("test"), "mac-container-tool should run successfully")

        // Volume should now exist
        let (_, listOutputAfter, _, _) = try run(arguments: ["volume", "list", "--quiet"])
        let volumeExistsAfter = listOutputAfter.contains(volumeName)
        #expect(volumeExistsAfter, "volume should be created")
    }

    @Test func testImplicitNamedVolumeReuse() throws {
        let testName = getTestName()
        let mac-container-toolName1 = "\(testName)_c1"
        let mac-container-toolName2 = "\(testName)_c2"
        let volumeName = "\(testName)_sharedvolume"

        defer {
            doRemoveIfExists(name: mac-container-toolName1, force: true)
            doRemoveIfExists(name: mac-container-toolName2, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        // First mac-container-tool - should auto-create volume
        let (_, _, _, status1) = try run(arguments: [
            "run",
            "--name",
            mac-container-toolName1,
            "-v", "\(volumeName):/data",
            alpine,
            "sh", "-c", "echo 'first' > /data/test.txt",
        ])

        #expect(status1 == 0, "first mac-container-tool should succeed")

        // Second mac-container-tool - should reuse existing volume
        let (_, _, _, status2) = try run(arguments: [
            "run",
            "--name",
            mac-container-toolName2,
            "-v", "\(volumeName):/data",
            alpine,
            "cat", "/data/test.txt",
        ])

        #expect(status2 == 0, "second mac-container-tool should succeed")
    }

    @Test func testVolumePruneNoVolumes() throws {
        // Prune with no volumes should succeed with 0 reclaimed
        let (_, _, error, status) = try run(arguments: ["volume", "prune"])
        if status != 0 {
            throw CLIError.executionFailed("volume prune failed: \(error)")
        }

        #expect(error.contains("Zero KB"), "should show no space reclaimed")
    }

    @Test func testVolumePruneUnusedVolumes() throws {
        let testName = getTestName()
        let volumeName1 = "\(testName)_vol1"
        let volumeName2 = "\(testName)_vol2"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName1)
        doVolumeDeleteIfExists(name: volumeName2)

        defer {
            doVolumeDeleteIfExists(name: volumeName1)
            doVolumeDeleteIfExists(name: volumeName2)
        }

        try doVolumeCreate(name: volumeName1)
        try doVolumeCreate(name: volumeName2)
        let (_, listBefore, _, statusBefore) = try run(arguments: ["volume", "list", "--quiet"])
        #expect(statusBefore == 0)
        #expect(listBefore.contains(volumeName1))
        #expect(listBefore.contains(volumeName2))

        // Prune should remove both
        let (_, output, error, status) = try run(arguments: ["volume", "prune"])
        if status != 0 {
            throw CLIError.executionFailed("volume prune failed: \(error)")
        }

        #expect(output.contains(volumeName1) || !output.contains("No volumes to prune"), "should prune volume1")
        #expect(output.contains(volumeName2) || !output.contains("No volumes to prune"), "should prune volume2")
        #expect(error.contains("Reclaimed"), "should show reclaimed space")

        // Verify volumes are gone
        let (_, listAfter, _, statusAfter) = try run(arguments: ["volume", "list", "--quiet"])
        #expect(statusAfter == 0)
        #expect(!listAfter.contains(volumeName1), "volume1 should be pruned")
        #expect(!listAfter.contains(volumeName2), "volume2 should be pruned")
    }

    @Test func testVolumePruneSkipsVolumeInUse() throws {
        let testName = getTestName()
        let volumeInUse = "\(testName)_inuse"
        let volumeUnused = "\(testName)_unused"
        let mac-container-toolName = "\(testName)_c1"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeInUse)
        doVolumeDeleteIfExists(name: volumeUnused)
        doRemoveIfExists(name: mac-container-toolName, force: true)

        defer {
            try? doStop(name: mac-container-toolName)
            doRemoveIfExists(name: mac-container-toolName, force: true)
            doVolumeDeleteIfExists(name: volumeInUse)
            doVolumeDeleteIfExists(name: volumeUnused)
        }

        try doVolumeCreate(name: volumeInUse)
        try doVolumeCreate(name: volumeUnused)
        try doLongRun(name: mac-container-toolName, args: ["-v", "\(volumeInUse):/data"])
        try waitForContainerRunning(mac-container-toolName)

        // Prune should only remove the unused volume
        let (_, _, error, status) = try run(arguments: ["volume", "prune"])
        if status != 0 {
            throw CLIError.executionFailed("volume prune failed: \(error)")
        }

        // Verify in-use volume still exists
        let (_, listAfter, _, statusAfter) = try run(arguments: ["volume", "list", "--quiet"])
        #expect(statusAfter == 0)
        #expect(listAfter.contains(volumeInUse), "volume in use should NOT be pruned")
        #expect(!listAfter.contains(volumeUnused), "unused volume should be pruned")

        try doStop(name: mac-container-toolName)
        doRemoveIfExists(name: mac-container-toolName, force: true)
        doVolumeDeleteIfExists(name: volumeInUse)
    }

    @Test func testVolumePruneSkipsVolumeAttachedToStoppedContainer() async throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"
        let mac-container-toolName = "\(testName)_c1"

        // Clean up any existing resources from previous runs
        doVolumeDeleteIfExists(name: volumeName)
        doRemoveIfExists(name: mac-container-toolName, force: true)

        defer {
            doRemoveIfExists(name: mac-container-toolName, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        try doVolumeCreate(name: volumeName)
        try doCreate(name: mac-container-toolName, image: alpine, volumes: ["\(volumeName):/data"])
        try await Task.sleep(for: .seconds(1))

        // Prune should NOT remove the volume (mac-container-tool exists, even if stopped)
        let (_, _, error, status) = try run(arguments: ["volume", "prune"])
        if status != 0 {
            throw CLIError.executionFailed("volume prune failed: \(error)")
        }

        let (_, listAfter, _, statusAfter) = try run(arguments: ["volume", "list", "--quiet"])
        #expect(statusAfter == 0)
        #expect(listAfter.contains(volumeName), "volume attached to stopped mac-container-tool should NOT be pruned")

        doRemoveIfExists(name: mac-container-toolName, force: true)
        let (_, _, error2, status2) = try run(arguments: ["volume", "prune"])
        if status2 != 0 {
            throw CLIError.executionFailed("volume prune failed: \(error2)")
        }

        // Verify volume is gone
        let (_, listFinal, _, statusFinal) = try run(arguments: ["volume", "list", "--quiet"])
        #expect(statusFinal == 0)
        #expect(!listFinal.contains(volumeName), "volume should be pruned after mac-container-tool is deleted")
    }

    // MARK: - Delete validation tests

    @Test func testVolumeDeleteNoArgs() throws {
        let (_, _, _, status) = try run(arguments: ["volume", "delete"])
        #expect(status != 0, "Expected non-zero exit when no args and no --all")
    }

    @Test func testVolumeDeleteExplicitNamesConflictWithAll() throws {
        let (_, _, error, status) = try run(arguments: ["volume", "delete", "--all", "some-volume"])
        #expect(status != 0, "Expected non-zero exit for conflicting flags")
        #expect(error.contains("conflict"))
    }

    // MARK: - Inspect validation tests

    @Test func testVolumeInspectMissingFails() throws {
        let (_, _, error, status) = try run(arguments: ["volume", "inspect", "definitely-missing-volume"])
        #expect(status != 0, "Expected non-zero exit for missing volume")
        #expect(error.contains("volume not found"))
    }

    // MARK: - Journal option tests

    @Test func testVolumeCreateWithJournalOrdered() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"

        doVolumeDeleteIfExists(name: volumeName)
        defer { doVolumeDeleteIfExists(name: volumeName) }

        let (_, _, error, status) = try run(arguments: [
            "volume", "create", "--opt", "journal=ordered", volumeName,
        ])
        #expect(status == 0, "volume create with journal=ordered should succeed: \(error)")

        let (_, listOutput, _, listStatus) = try run(arguments: ["volume", "list", "--quiet"])
        #expect(listStatus == 0)
        #expect(listOutput.contains(volumeName), "journaled volume should appear in list")
    }

    @Test func testVolumeCreateWithJournalAndSize() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"

        doVolumeDeleteIfExists(name: volumeName)
        defer { doVolumeDeleteIfExists(name: volumeName) }

        let (_, _, error, status) = try run(arguments: [
            "volume", "create", "--opt", "journal=writeback:64m", volumeName,
        ])
        #expect(status == 0, "volume create with journal=writeback:64m should succeed: \(error)")
    }

    @Test func testVolumeCreateWithInvalidJournalModeErrors() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"

        doVolumeDeleteIfExists(name: volumeName)
        defer { doVolumeDeleteIfExists(name: volumeName) }

        let (_, _, _, status) = try run(arguments: [
            "volume", "create", "--opt", "journal=none", volumeName,
        ])
        #expect(status != 0, "volume create with journal=none should fail")
    }

    @Test func testJournaledVolumeDataPersistence() throws {
        let testName = getTestName()
        let volumeName = "\(testName)_vol"
        let mac-container-tool1Name = "\(testName)_c1"
        let mac-container-tool2Name = "\(testName)_c2"
        let testData = "journaled-data"
        let testFile = "/data/test.txt"

        doVolumeDeleteIfExists(name: volumeName)
        doRemoveIfExists(name: mac-container-tool1Name, force: true)
        doRemoveIfExists(name: mac-container-tool2Name, force: true)

        defer {
            try? doStop(name: mac-container-tool1Name)
            doRemoveIfExists(name: mac-container-tool1Name, force: true)
            try? doStop(name: mac-container-tool2Name)
            doRemoveIfExists(name: mac-container-tool2Name, force: true)
            doVolumeDeleteIfExists(name: volumeName)
        }

        let (_, _, createError, createStatus) = try run(arguments: [
            "volume", "create", "--opt", "journal=ordered", volumeName,
        ])
        guard createStatus == 0 else {
            throw CLIError.executionFailed("volume create failed: \(createError)")
        }

        try doLongRun(name: mac-container-tool1Name, args: ["-v", "\(volumeName):/data"])
        try waitForContainerRunning(mac-container-tool1Name)
        _ = try doExec(name: mac-container-tool1Name, cmd: ["sh", "-c", "echo '\(testData)' > \(testFile)"])
        try doStop(name: mac-container-tool1Name)

        try doLongRun(name: mac-container-tool2Name, args: ["-v", "\(volumeName):/data"])
        try waitForContainerRunning(mac-container-tool2Name)
        var output = try doExec(name: mac-container-tool2Name, cmd: ["cat", testFile])
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output == testData, "expected '\(testData)', got '\(output)'")

        try doStop(name: mac-container-tool2Name)
        try doVolumeDelete(name: volumeName)
    }
}
