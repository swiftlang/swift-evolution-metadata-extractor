// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Testing
import Foundation

import EvolutionMetadataModel // public interface, @testable not requred
@testable import EvolutionMetadataExtraction

// MARK: Test Utility Functions

func urlForSnapshot(named snapshotName: String) throws -> URL {
    try #require(Bundle.module.url(forResource: snapshotName, withExtension: "evosnapshot", subdirectory: "Resources"), "Unable to find snapshot \(snapshotName).evosnapshot in test bundle resources.")
}

var allTestSnapshotNames: [String] {
    get throws {
        // Typecase to [URL] required for Linux where type returned seems to be [NSURL]
        let snapshotURLs = try #require(Bundle.module.urls(forResourcesWithExtension: "evosnapshot", subdirectory: "Resources"), "Unable to find .evosnapshot snapshots in test bundle resources.") as [URL]
        return snapshotURLs.map { $0.deletingPathExtension().lastPathComponent }
    }
}

func proposalURLs() throws -> [URL] {
    // Typecase to [URL] required for Linux where type returned seems to be [NSURL]
    try #require(Bundle.module.urls(forResourcesWithExtension: "md", subdirectory: "Resources/ProposalFiles"), "Unable to find proposal files in test bundle resources.") as [URL]
}

func expectedResultsForSnapshot(named snapshotName: String) throws -> EvolutionMetadata {
    let snapshotURL = try urlForSnapshot(named: snapshotName)
    let expectedResultsURL = snapshotURL.appending(component: "expected-results.json")
    let expectedJSONData = try Data(contentsOf: expectedResultsURL)
    return try JSONDecoder().decode(EvolutionMetadata.self, from:expectedJSONData)
}

func extractionDateForSnapshot(named snapshotName: String) throws -> Date {
    let expectedResults = try expectedResultsForSnapshot(named: snapshotName)
    return try #require(ISO8601DateFormatter().date(from: expectedResults.creationDate), "Date cannot be created from creationDate string '\(expectedResults.creationDate)'")
}

func data(forResource name: String, withExtension ext: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"), "Unable to find resource \(name).\(ext) in test bundle resources.")
    let data = try Data(contentsOf: url)
    return data
}

func string(forResource name: String, withExtension ext: String) throws -> String {
    let data = try data(forResource: name, withExtension: ext)
    let string = try #require(String(data: data, encoding: .utf8), "Unable to make string from contents of \(name).\(ext)")
    return string
}

// Convenience to write expected and actual metadata files to disk for comparison in a diff tool
func writeJSONFilesToPath(expected: Data, actual: Data, path: String, prefix: String? = nil) throws {
    let filePrefix: String
    if let prefix { filePrefix = "\(prefix)-" } else { filePrefix = "" }
    try expected.write(to: FileUtilities.expandedAndStandardizedURL(for: path).appending(path: "\(filePrefix)expected.json"))
    try actual.write(to: FileUtilities.expandedAndStandardizedURL(for: path).appending(path: "\(filePrefix)actual.json"))
}
