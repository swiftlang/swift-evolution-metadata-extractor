
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Testing
import Foundation

@testable import EvolutionMetadataModel
@testable import EvolutionMetadataExtraction

struct `Extraction tests` {

    struct `All proposals` {
        private var snapshotURL: URL
        private var extractionJob: ExtractionJob
        private var extractedEvolutionMetadata: EvolutionMetadata

        init() async throws {
            snapshotURL = try urlForSnapshot(named: "AllProposals")
            extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
            extractedEvolutionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
        }

        @Test func `Extracted metadata`() async throws {
            let expectedResults = try #require(extractionJob.expectedResults, "Snapshot from source '\(snapshotURL.absoluteString)' does not contain expected results.")

            // Check top-level properties
            #expect(extractedEvolutionMetadata.commit == expectedResults.commit)
            #expect(extractedEvolutionMetadata.creationDate == expectedResults.creationDate)
            #expect(extractedEvolutionMetadata.implementationVersions == expectedResults.implementationVersions)
            #expect(extractedEvolutionMetadata.schemaVersion == expectedResults.schemaVersion)
            #expect(extractedEvolutionMetadata.toolVersion == expectedResults.toolVersion)
        }

        // Check proposals
        @Test func `Expected proposals`() async throws {
            let expectedResults = try #require(extractionJob.expectedResults, "Snapshot at '\(snapshotURL.absoluteString)' does not contain expected results.")
            let expectedResultsByProposalID = expectedResults.proposals.reduce(into: [:]) { $0[$1.id] = $1 }

            for newProposal in extractedEvolutionMetadata.proposals {
                let id = newProposal.id
                guard !id.isEmpty  else {
                    continue
                }

                guard let sourceProposal = expectedResultsByProposalID[id] else {
                    Issue.record("Unable to find id \(id) in expected results.")
                    continue
                }

                #expect(newProposal == sourceProposal)
            }
        }

        // Check the generated JSON to catch issues such as removing properties from the schema
        @Test func `Serialization`() throws {
            let expectedResultsURL = snapshotURL.appending(path: "expected-results.json")
            let expectedJSONData = try Data(contentsOf: expectedResultsURL)
            let actualJSONData = try extractedEvolutionMetadata.jsonRepresentation
            #expect(expectedJSONData == actualJSONData)

            // Uncomment to write full JSON files out to compare in a diff tool
            // try writeJSONFilesToPath(expected: expectedJSONData, actual: actualJSONData, path: "~/Desktop")
        }
    }
    
    @Test func `Warnings and errors`() async throws {
        
        let snapshotURL = try urlForSnapshot(named: "Malformed")
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
        let expectedResults = try #require(extractionJob.expectedResults, "No expected results found in bundle '\(snapshotURL.absoluteString)'")
        
        // VALIDATION ENHANCEMENT: Tools like Xcode like to add a newline character to empty files
        // Possibly instead of using 0007-empty-file.md to test, test separately?
        // Or test that the file hasn't been corrupted. (Can you even check it into github?)

        let extractionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
        
        // This test zips the extraction results with the expected results
        // If the two arrays don't have the same count, the test data itself has an error
        #expect(extractionMetadata.proposals.count == expectedResults.proposals.count)
        
        for (actualResult, expectedResult) in zip(extractionMetadata.proposals, expectedResults.proposals) {
            #expect(actualResult == expectedResult)
        }
    }
    
    // The lines of text in review-dates-good.txt are status headers from swift-evolution repository history
    @Test func `Good dates`() throws {
        
        let reviewDatesContents = try string(forResource: "review-dates-good", withExtension: "txt")
        
        let statusStrings = reviewDatesContents.split(separator: "\n")
        for statusString in statusStrings {
            // NOTE: This is something that should be validated!
            // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
            let match = try #require(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )
            
            let statusDetail = String(match.1)
            
            #expect(StatusExtractor.datesForString(statusDetail, processingDate: Date.now) != nil, "Unable to parse '\(statusDetail)'")
        }
    }
    
    // The lines of text in review-dates-bad.txt are status headers from swift-evolution repository history
    @Test func `Bad dates`() throws {
        
        let reviewDatesContents = try string(forResource: "review-dates-bad", withExtension: "txt")

        let statusStrings = reviewDatesContents.split(separator: "\n")
        for statusString in statusStrings {
            // NOTE: This is something that should be validated!
            // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
            let match = try #require(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )
            
            let statusDetail = String(match.1)
            
            #expect(StatusExtractor.datesForString(statusDetail, processingDate: Date.now) == nil, "Unexpectedly able to parse '\(statusDetail)'")
        }
    }
    
    /* Tests for breaking schema changes by serializing using the current model and then attempting to decode using a baseline version of the model from the last major schema release. The baseline model is located in the BaselineModel directory.
     
        Note that this test assumes that the referenced snapshots are updated to be correct for the current model.
     */
    @Test(arguments: [
        "AllProposals",
        "Malformed",
    ])
    func `Breaking changes`(snapshotName: String) async throws {

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let snapshotURL = try urlForSnapshot(named: snapshotName)
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
        let extractedMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
        let data = try encoder.encode(extractedMetadata)
        _ = try decoder.decode(EvolutionMetadata_v1.self, from: data)
    }

    /* Test that if an unknown proposal status is encountered, decoding does not fail and decodes to an .error status with the unknown status value as part of the associated reason string.
        The 'unknown-status.json' file contains the metadata of a single proposal with the fictional unknown status of 'appealed'.
     */
    @Test func `Unknown status`() throws {
        let unknownStatusData = try data(forResource: "unknown-status", withExtension: "json")
        let proposal = try JSONDecoder().decode(Proposal.self, from: unknownStatusData)
        #expect(proposal.status == .unknownStatus("appealed"))
    }
}

// MARK: - Helpers

private func urlForSnapshot(named snapshotName: String) throws -> URL {
    try #require(Bundle.module.url(forResource: snapshotName, withExtension: "evosnapshot", subdirectory: "Resources"), "Unable to find snapshot \(snapshotName).evosnapshot in test bundle resources.")
}

private func data(forResource name: String, withExtension ext: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"), "Unable to find resource \(name).\(ext) in test bundle resources.")
    let data = try Data(contentsOf: url)
    return data
}

private func string(forResource name: String, withExtension ext: String) throws -> String {
    let data = try data(forResource: name, withExtension: ext)
    let string = try #require(String(data: data, encoding: .utf8), "Unable to make string from contents of \(name).\(ext)")
    return string
}

// Convenience to write expected and actual metadata files to disk for comparison in a diff tool
private func writeJSONFilesToPath(expected: Data, actual: Data, path: String, prefix: String? = nil) throws {
    let filePrefix: String
    if let prefix { filePrefix = "\(prefix)-" } else { filePrefix = "" }
    try expected.write(to: FileUtilities.expandedAndStandardizedURL(for: path).appending(path: "\(filePrefix)expected.json"))
    try actual.write(to: FileUtilities.expandedAndStandardizedURL(for: path).appending(path: "\(filePrefix)actual.json"))
}
