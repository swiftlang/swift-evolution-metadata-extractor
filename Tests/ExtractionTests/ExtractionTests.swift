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
            extractionJob = try await ExtractionJob.makeExtractionJob(source: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
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

            let extractionJob = try await ExtractionJob.makeExtractionJob(source: .snapshot(snapshotURL), output: .none, ignorePreviousResults: args.ignorePreviousResults, forcedExtractionIDs: args.forceExtractionIDs)

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

        /* The snapshot 'WithUpdates' contains previous results and is used to test the logic that identifies
           and processes only proposals that are new or updated.

           The snapshot 'WithUpdates-BaseCommit' is a snapshot with the previous state.

           The metadata extracted from the 'WithUpdates-BaseCommit' snapshot serves as the previous results of the
           'WithUpdates' snapshot used in the `Reuse prior results` test.

           When the schema or tool versions change, test snapshots are regenerated for the new versions.

           This test checks the invariant that the 'WithUpdates-BaseCommit' expected results equals the extracted results
           and the prior results of the 'WithUpdates' snapshot
        */
        @Test func `Last expected equals prior results`() async throws {
            let snapshotURL = try urlForSnapshot(named: "WithUpdates")
            let snapshot = try await Snapshot.makeSnapshot(snapshotURL: snapshotURL, destURL: nil, ignorePreviousResults: false, extractionDate: Date())

            let priorSnapshotURL = try urlForSnapshot(named: "WithUpdates-BaseCommit")
            let extractionJob = try await ExtractionJob.makeExtractionJob(source: .snapshot(priorSnapshotURL), output: .none, ignorePreviousResults: false)
            let priorSnapshot = try #require(extractionJob.snapshot)

            let previousResults = try #require(snapshot.previousResults)
            let priorExpectedResults = try #require(priorSnapshot.expectedResults)
            #expect(priorExpectedResults == previousResults)

            let calculatedPriorResults = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
            #expect(calculatedPriorResults == previousResults)
        }
    }

    // MARK: -

    private static var warningsAndErrorsArguments: Zip2Sequence<[Proposal], [Proposal]> {
      get async throws {
        let snapshotURL = try urlForSnapshot(named: "Malformed")
        let source: ExtractionJob.Source = .snapshot(snapshotURL)
        let extractionJob = try await ExtractionJob.makeExtractionJob(source: source, output: .none, ignorePreviousResults: true)
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
    
    @Test func `Exit failure for validation report with errors`() async throws {
        await #expect(processExitsWith: .failure) {
            let snapshotURL = try urlForSnapshot(named: "Malformed")
            let source: ExtractionJob.Source = .snapshot(snapshotURL)
            let extractionJob = try await ExtractionJob.makeExtractionJob(source: source, output: .validationReport(URL.standardOutURL), ignorePreviousResults: true)
            try await extractionJob.run()
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
        let extractionJob = try await ExtractionJob.makeExtractionJob(source: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
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

    @Test(arguments: [
        (filename: "old-schema-version", currentSchema: false, currentTool: true, currentMetadata: false),
        (filename: "old-tool-version", currentSchema: true, currentTool: false, currentMetadata: false),
        (filename: "current-metadata-versions", currentSchema: true, currentTool: true, currentMetadata: true),
    ])
    func `Metadata version changes`(argument: (filename: String, currentSchema: Bool, currentTool: Bool, currentMetadata: Bool)) throws {
        let url = try #require(Bundle.module.url(forResource: argument.filename, withExtension: "json", subdirectory: "Resources/MetadataVersions"), "Unable to find resource \(argument.filename).json in test bundle resources.")
        let evolutionMetadata = try #require(try FileUtilities.decode(EvolutionMetadata.self, from: url, required: true))
        #expect(evolutionMetadata.hasCurrentSchemaVersion == argument.currentSchema)
        #expect(evolutionMetadata.hasCurrentToolVersion == argument.currentTool)
        #expect(evolutionMetadata.hasCurrentMetadataVersions == argument.currentMetadata)
    }

    @Test(arguments:
            [(filename: "old-schema-version", expectsNil: true, fileExists: true),
             (filename: "old-tool-version", expectsNil: true, fileExists: true),
             (filename: "current-metadata-versions", expectsNil: false, fileExists: true),
             (filename: "missing-file", expectsNil: true, fileExists: false)],
          [true, false])
    func `Previous results`(argument: (filename: String, expectsNil: Bool, fileExists: Bool), ignorePreviousResults: Bool) async throws {
        let url = Bundle.module.url(forResource: argument.filename, withExtension: "json", subdirectory: "Resources/MetadataVersions")
        let sourceURL: URL
        if argument.fileExists {
            sourceURL = try #require(url, "Unable to find resource \(argument.filename).json in test bundle resources.")
        } else {
            sourceURL = Bundle.module.bundleURL.appending(components: "Resources", "MetadataVersions", argument.filename).appendingPathExtension("json")
        }
        let previousResults = try await ExtractionJob.previousResults(from: sourceURL, ignorePreviousResults: ignorePreviousResults)
        if argument.expectsNil || ignorePreviousResults { #expect(previousResults == nil) }
        else { #expect(previousResults != nil) }
    }

    @Test(arguments: try allTestSnapshotNames)
    func `Check snapshot versions`(snapshotName: String) async throws {
        let snapshotURL = try urlForSnapshot(named: snapshotName)
        let snapshot = try await Snapshot.makeSnapshot(snapshotURL: snapshotURL, destURL: nil, ignorePreviousResults: false, extractionDate: Date())
        let expectedResults = try #require(snapshot.expectedResults)
        #expect(expectedResults.hasCurrentSchemaVersion == true, "Expected results for snapshot '\(snapshotName)' does not have the current schema version '\(EvolutionMetadata.schemaVersion)'. Update snapshot to current schema version.")
        #expect(expectedResults.hasCurrentToolVersion == true, "Expected results for snapshot '\(snapshotName)' does not have the current tool version '\(ToolVersion.version)'. Update snapshot to current tool version.")
        #expect(expectedResults.hasCurrentMetadataVersions == true)
    }
}

// MARK: - Extensions

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
