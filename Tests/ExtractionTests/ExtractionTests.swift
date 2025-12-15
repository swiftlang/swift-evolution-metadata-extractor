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

@Suite
struct `Extraction Tests` {

    @Suite
    struct `All Proposals` {
        private var snapshotURL: URL
        private var extractionJob: ExtractionJob
        private var extractedEvolutionMetadata: EvolutionMetadata

        init() async throws {
            snapshotURL = try urlForSnapshot(named: "AllProposals")
            extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
            extractedEvolutionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
        }

        @Test func `Extracted metadata`() async throws {
            let expectedResults = try #require(extractionJob.snapshot?.expectedResults, "Snapshot from source '\(snapshotURL.absoluteString)' does not contain expected results.")

            // Check top-level properties
            #expect(extractedEvolutionMetadata.commit == expectedResults.commit)
            #expect(extractedEvolutionMetadata.creationDate == expectedResults.creationDate)
            #expect(extractedEvolutionMetadata.implementationVersions == expectedResults.implementationVersions)
            #expect(extractedEvolutionMetadata.schemaVersion == expectedResults.schemaVersion)
            #expect(extractedEvolutionMetadata.toolVersion == expectedResults.toolVersion)
        }

        // Check proposals
        @Test func `Expected proposals`() async throws {
            let expectedResults = try #require(extractionJob.snapshot?.expectedResults, "Snapshot at '\(snapshotURL.absoluteString)' does not contain expected results.")
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
        @Test func `Expected serialization`() throws {
            let expectedResultsURL = snapshotURL.appending(path: "expected-results.json")
            let expectedJSONData = try Data(contentsOf: expectedResultsURL)
            let actualJSONData = try extractedEvolutionMetadata.jsonRepresentation
            #expect(expectedJSONData == actualJSONData)

            // Uncomment to write full JSON files out to compare in a diff tool
            // try writeJSONFilesToPath(expected: expectedJSONData, actual: actualJSONData, path: "~/Desktop")
        }
    }

    @Suite
    struct `Prior Results` {

        private var expectedUpdatedProposalIDs: [String : [String]] = [
            "SameCommit" : [],
            "WithUpdates" : ["SE-0317", "SE-0461", "SE-0490", "SE-0492", "SE-0493", "SE-0494", "SE-0495", "SE-0496", "SE-0497", "SE-0498"]
        ]

        private static var args: [Args] {
            [
                Args("SameCommit", true, []),
                Args("SameCommit", true, ["SE-0420", "SE-0080", "SE-0111"]),
                Args("SameCommit", false, []),
                Args("SameCommit", false, ["SE-0200"]),
                Args("SameCommit", false, ["SE-0345", "SE-0346", "SE-0347", "SE-0348"]),
                Args("SameCommit", false, ["SE-0420", "SE-0080", "SE-0111"]),
                Args("SameCommit", false, ["SE-0102", "SE-0099", "SE-0376", "SE-0245"]),
                Args("SameCommit", false, ["SE-0044", "SE-0055", "SE-0067", "SE-0074", "SE-0176", "SE-0433", "SE-0390", "SE-0208"]),
                Args("WithUpdates", true, []),
                Args("WithUpdates", true, ["SE-0088"]),
                Args("WithUpdates", false, []),
                Args("WithUpdates", false, ["SE-0230"]),
                Args("WithUpdates", false, ["SE-0245", "SE-0246", "SE-0247", "SE-0248"]),
                Args("WithUpdates", false, ["SE-0420", "SE-0092", "SE-0121"]),
                Args("WithUpdates", false, ["SE-0172", "SE-0098", "SE-0367", "SE-0254"]),
                Args("WithUpdates", false, ["SE-0043", "SE-0056", "SE-0063", "SE-0076", "SE-0178", "SE-0434", "SE-0391", "SE-0218"]),
            ]
        }

        @Test(arguments: args)
        func `Reuse prior results`(args: Args) async throws {
            let snapshotURL = try urlForSnapshot(named: args.snapshotName)

            let extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: args.ignorePreviousResults, forcedExtractionIDs: args.forceExtractionIDs)

            let proposalListingCount = try #require(extractionJob.snapshot?.proposalListing?.count)
            let expectedUpdatedProposalIDs = try #require(expectedUpdatedProposalIDs[args.snapshotName])

            // Concatenate, unique, and sort IDs for force extraction and expected updates
            let forceAndUpdateProposalIDs = Set<String>(args.forceExtractionIDs + expectedUpdatedProposalIDs ).sorted()
            let forceAndUpdateCount = forceAndUpdateProposalIDs.count

            let extractCount: Int; let reuseCount: Int
            if args.ignorePreviousResults {
                extractCount = proposalListingCount // ignorePreviousResults always extracts all
                reuseCount = 0
            } else {
                extractCount = forceAndUpdateCount
                reuseCount = proposalListingCount - forceAndUpdateCount
            }

            let (proposalSpecsToExtract, reusableProposals) = EvolutionMetadataExtractor.filterProposalSpecs(for: extractionJob)

            #expect(proposalSpecsToExtract.count == extractCount)
            #expect(reusableProposals.count == reuseCount)

            if !args.ignorePreviousResults {
                #expect(proposalSpecsToExtract.map(\.id) == forceAndUpdateProposalIDs)
            }

            let extractedMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
            let expectedResults = try #require(extractionJob.snapshot?.expectedResults, "Snapshot from source '\(snapshotURL.absoluteString)' does not contain expected results.")
            #expect(extractedMetadata == expectedResults)
        }
    }

    // MARK: -

    private static var warningsAndErrorsArguments: Zip2Sequence<[Proposal], [Proposal]> {
      get async throws {
        let snapshotURL = try urlForSnapshot(named: "Malformed")
        let source: ExtractionJob.Source = .snapshot(snapshotURL)
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: source, output: .none, ignorePreviousResults: true)
        let expectedResults = try #require(extractionJob.snapshot?.expectedResults, "No expected results found for extraction job with source '\(source)'")
        let extractionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)

        // This test zips the extraction results with the expected results. If
        // the two arrays don't have the same count, the test data itself may have an error.
        try #require(extractionMetadata.proposals.count == expectedResults.proposals.count)

        return zip(extractionMetadata.proposals, expectedResults.proposals)
      }
    }

    // VALIDATION ENHANCEMENT: Tools like Xcode like to add a newline character to empty files
    // Possibly instead of using 0007-empty-file.md to test, test separately?
    // Or test that the file hasn't been corrupted. (Can you even check it into github?)
    @Test(arguments: try await warningsAndErrorsArguments)
    func `Warnings and errors`(actualResult: Proposal, expectedResult: Proposal) async throws {
        #expect(actualResult == expectedResult)
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
    
    @Test(arguments: try {
        // The lines of text in review-dates-bad.txt are status headers from swift-evolution repository history
        let reviewDatesContents = try string(forResource: "review-dates-bad", withExtension: "txt")
        return reviewDatesContents.split(separator: "\n").map(String.init)
    }())
    func `Bad dates`(statusString: String) throws {

        // NOTE: This is something that should be validated!
        // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
        let match = try #require(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )

        let statusDetail = String(match.1)

        #expect(StatusExtractor.datesForString(statusDetail, processingDate: Date.now) == nil, "Unexpectedly able to parse '\(statusDetail)'")
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
    
    @Suite
    struct `Snapshot Writing` {

        /*  The snapshot command can generate a new snapshot from an existing snapshot. This would typically be done to
            update the expected results of a snapshot after a change in the metadata schema or expected behavior.
         
            This test exercises that path by ensuring that the generated snapshot is identical to the source snapshot.
         */
        @Test(arguments: [
            "AllProposals",
            "Malformed",
            "SameCommit",
            "WithUpdates",
            "AdHoc"
        ])
        func `Update snapshot`(snapshotName: String) async throws {
            let sourceURL = try urlForSnapshot(named: snapshotName)
            let destURL = FileManager.default.temporaryDirectory.appending(components:"_Test_Snapshots",  UUID().uuidString, sourceURL.lastPathComponent)
            
            let extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(sourceURL), output: .snapshot(destURL), ignorePreviousResults: false)
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
            
            // Use expected extraciton date in new snapshot for identical metadata
            let extractionDate = try extractionDateForSnapshot(named: snapshotName)

            let extractionJob = try await ExtractionJob.makeExtractionJob(from: .files(sourceURLs), output: .snapshot(destURL), ignorePreviousResults: true, extractionDate: extractionDate)
            try await extractionJob.run()

            let sourceSubpaths = try FileManager.default.subpathsOfDirectory(atPath: adHocSnapshotURL.path())

            for sourceSubpath in sourceSubpaths {
                let sourcePath = adHocSnapshotURL.appending(path: sourceSubpath).path(percentEncoded: false)
                let destinationPath = destURL.appending(path: sourceSubpath).path(percentEncoded: false)
                #expect(FileManager.default.contentsEqual(atPath: sourcePath, andPath: destinationPath), "Subpath '\(sourceSubpath)' Failed")
            }
        }
    }
}

// MARK: - Helpers

extension Proposal: CustomTestStringConvertible {
    public var testDescription: String { id.isEmpty ? "No ID" : id }
}

extension `Extraction Tests`.`Prior Results` {

    struct Args: CustomTestStringConvertible {
        let snapshotName: String
        let ignorePreviousResults: Bool
        let forceExtractionIDs: [String]

        init(_ snapshotName: String, _ ignorePreviousResults: Bool, _ forceExtractionIDs: [String]) {
            self.snapshotName = snapshotName
            self.ignorePreviousResults = ignorePreviousResults
            self.forceExtractionIDs = forceExtractionIDs
        }

        public var testDescription: String {
            var forceSummary: String
            if ignorePreviousResults {
                forceSummary = ", force all"
                if forceExtractionIDs.count > 0 {
                    forceSummary += " + \(forceExtractionIDs.count)"
                }
            } else if forceExtractionIDs.count > 0 {
                forceSummary = ", force \(forceExtractionIDs.count)"
            } else {
                forceSummary = ", force none"
            }
            return snapshotName.camelCaseToSentence() + forceSummary
        }
    }
}

private extension String {
    func camelCaseToSentence() -> String {
        unicodeScalars.dropFirst().reduce(String(prefix(1))) {
            CharacterSet.uppercaseLetters.contains($1)
            ? $0 + " " + String($1).lowercased()
                : $0 + String($1)
        }
    }
}

private func urlForSnapshot(named snapshotName: String) throws -> URL {
    try #require(Bundle.module.url(forResource: snapshotName, withExtension: "evosnapshot", subdirectory: "Resources"), "Unable to find snapshot \(snapshotName).evosnapshot in test bundle resources.")
}

private func proposalURLs() throws -> [URL] {
    // Typecase to [URL] required for Linux where type returned seems to be [NSURL]
    try #require(Bundle.module.urls(forResourcesWithExtension: "md", subdirectory: "Resources/ProposalFiles"), "Unable to find proposal files in test bundle resources.") as [URL]
}

private func expectedResultsForSnapshot(named snapshotName: String) throws -> EvolutionMetadata {
    let snapshotURL = try urlForSnapshot(named: snapshotName)
    let expectedResultsURL = snapshotURL.appending(component: "expected-results.json")
    let expectedJSONData = try Data(contentsOf: expectedResultsURL)
    return try JSONDecoder().decode(EvolutionMetadata.self, from:expectedJSONData)
}

private func extractionDateForSnapshot(named snapshotName: String) throws -> Date {
    let expectedResults = try expectedResultsForSnapshot(named: snapshotName)
    return try #require(ISO8601DateFormatter().date(from: expectedResults.creationDate), "Date cannot be created from creationDate string '\(expectedResults.creationDate)'")
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
