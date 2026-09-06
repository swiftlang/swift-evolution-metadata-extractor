// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Testing
import Foundation

@testable import EvolutionMetadataModel
@testable import EvolutionMetadataExtraction

@Suite
struct `Snapshot Writing` {

    /*  The snapshot command can generate a new snapshot from an existing snapshot. This would typically be done to
        update the expected results of a snapshot after a change in the metadata schema or expected behavior.

        This test exercises that path by ensuring that the generated snapshot is identical to the source snapshot.
     */
    @Test(arguments: try allTestSnapshotNames)
    func `Update snapshot`(snapshotName: String) async throws {
        let sourceURL = try urlForSnapshot(named: snapshotName)
        let destURL = FileManager.default.temporaryDirectory.appending(components:"_Test_Snapshots",  UUID().uuidString, sourceURL.lastPathComponent)

        let extractionJob = try await ExtractionJob.makeExtractionJob(source: .snapshot(sourceURL), output: .snapshot(destURL), ignorePreviousResults: false)
        try await extractionJob.run()

        let sourceSubpaths = try FileManager.default.subpathsOfDirectory(atPath: sourceURL.path())

        for sourceSubpath in sourceSubpaths {
            let sourcePath = sourceURL.appending(path: sourceSubpath).path(percentEncoded: false)
            let destinationPath = destURL.appending(path: sourceSubpath).path(percentEncoded: false)
            #expect(FileManager.default.contentsEqual(atPath: sourcePath, andPath: destinationPath))
        }
    }

    @Test func `Create ad hoc snapshot`() async throws {
        let snapshotName = "AdHoc"
        let sourceURLs = try proposalURLs()
        let destURL = FileManager.default.temporaryDirectory.appending(components:UUID().uuidString, snapshotName + ".evosnapshot")
        let adHocSnapshotURL = try urlForSnapshot(named: snapshotName)

        // Use expected extraction date in new snapshot for identical metadata
        let extractionDate = try extractionDateForSnapshot(named: snapshotName)

        let extractionJob = try await ExtractionJob.makeExtractionJob(source: .files(sourceURLs), output: .snapshot(destURL), ignorePreviousResults: true, extractionDate: extractionDate)
        try await extractionJob.run()

        let sourceSubpaths = try FileManager.default.subpathsOfDirectory(atPath: adHocSnapshotURL.path())

        for sourceSubpath in sourceSubpaths {
            let sourcePath = adHocSnapshotURL.appending(path: sourceSubpath).path(percentEncoded: false)
            let destinationPath = destURL.appending(path: sourceSubpath).path(percentEncoded: false)
            #expect(FileManager.default.contentsEqual(atPath: sourcePath, andPath: destinationPath), "Subpath '\(sourceSubpath)' Failed")
        }
    }
}
