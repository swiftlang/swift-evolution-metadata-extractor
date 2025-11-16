
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

/* The swift-evolution-extraction tool can perform three tasks:
 1. Extract: Extraction of metadata to produce a json file
 2. Validate: Validation of proposals to ensure metadata can be extracted as expected (Not yet implemented)
 3. Snapshot: Capture a local snapshot of inputs and expected results that can be used for local testing
 
 An `ExtractionJob` captures all of the required inputs and potential output locations.
 */
public struct ExtractionJob: Sendable {
    public enum Source: Sendable, Codable, Equatable {
        case network
        case snapshot(URL)
    }
    
    public enum Output: Sendable, Codable, Equatable {
        case metadataJSON(URL)
        case snapshot(URL)
        case validationReport
        case none
    }
    
    struct JobMetadata {
        let toolVersion: String
        let commit: String?
        let extractionDate: Date
    }

    let source: Source
    let branchInfo: GitHubBranch?
    let proposalListing: [GitHubContentItem]? // Ad-hoc snapshots may not have these
    let proposalSpecs: [ProposalSpec]
    let previousResults: EvolutionMetadata?
    let expectedResults: EvolutionMetadata?
    let forcedExtractionIDs: [String]
    let jobMetadata: JobMetadata
    let output: Output
    let temporarySnapshotDirectory: URL?
    var temporaryProposalsDirectory: URL? { temporarySnapshotDirectory?.appending(component: "proposals") }

    private init(source: Source, output: Output, branchInfo: GitHubBranch? = nil, proposalListing: [GitHubContentItem]?, proposalSpecs: [ProposalSpec], previousResults: EvolutionMetadata?, expectedResults: EvolutionMetadata?, forcedExtractionIDs: [String], jobMetadata: JobMetadata) {
        self.source = source
        self.branchInfo = branchInfo
        self.proposalListing = proposalListing
        self.proposalSpecs = proposalSpecs
        self.previousResults = previousResults
        self.expectedResults = expectedResults
        self.forcedExtractionIDs = forcedExtractionIDs
        self.output = output
        self.jobMetadata = jobMetadata
        self.temporarySnapshotDirectory = switch output {
            case .snapshot:
                FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
            default:
                nil
        }
    }
    
    public func run() async throws {
        // Extract Metadata
        let evolutionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: self)
        
        // Compare results against expected results, if extraction job has them
        compareResultsToExpectedValuesIfPresent(evolutionMetadata)
        
        // Output Results
        try outputResults(evolutionMetadata)

    }
    
    public static func makeExtractionJob(from source: Source, output: Output, ignorePreviousResults: Bool = false, forcedExtractionIDs: [String] = [], toolVersion: String = ToolVersion.version, extractionDate: Date = Date()) async throws -> ExtractionJob {
        switch source {
            case .network:
                try await makeNetworkExtractionJob(source: source, output: output, ignorePreviousResults: ignorePreviousResults, forcedExtractionIDs: forcedExtractionIDs, toolVersion: toolVersion, extractionDate: extractionDate)
            case .snapshot:
                try makeSnapshotExtractionJob(source: source, output: output, ignorePreviousResults: ignorePreviousResults, forcedExtractionIDs: forcedExtractionIDs, toolVersion: toolVersion, extractionDate: extractionDate)
        }
    }
}

// MARK: - Gather Job Requirements & Create

extension ExtractionJob {
    
    private static func makeNetworkExtractionJob(source: Source, output: Output, ignorePreviousResults: Bool, forcedExtractionIDs: [String], toolVersion: String, extractionDate: Date) async throws -> ExtractionJob {
        
        assert(source == .network, "makeNetworkExtractionJob() requires network source")
        
        async let previousResults = ignorePreviousResults ? nil : PreviousResultsFetcher.fetchPreviousResults()
        let mainBranchInfo = try await GitHubFetcher.fetchMainBranch()
        let proposalContentItems = try await GitHubFetcher.fetchProposalContentItems(for: mainBranchInfo.commit.sha)

        // The proposals/ directory may have subdirectories for
        // proposals from specific workgroups. For now, proposals
        // in those subdirectories are filtered out of this proposal
        // specs array.
        let proposalSpecs = proposalContentItems.enumerated().compactMap {
            $1.proposalSpec(sortIndex: $0)
        }

        let jobMetadata = JobMetadata(toolVersion: toolVersion, commit: mainBranchInfo.commit.sha, extractionDate: extractionDate)

        return ExtractionJob(source: source, output: output, branchInfo: mainBranchInfo, proposalListing: proposalContentItems, proposalSpecs: proposalSpecs, previousResults: try await previousResults, expectedResults: nil, forcedExtractionIDs: forcedExtractionIDs, jobMetadata: jobMetadata)
    }
    
    private static func makeSnapshotExtractionJob(source: Source, output: Output, ignorePreviousResults: Bool, forcedExtractionIDs: [String], toolVersion: String, extractionDate: Date) throws -> ExtractionJob {
        
        guard case let .snapshot(snapshotURL) = source else {
            fatalError("makeSnapshotExtractionJob() requires snapshot source")
        }
        
        // Argument validation should ensure correct values. Assert to catch problems in usage in tests.
        assert(snapshotURL.pathExtension == "evosnapshot", "Snapshot URL must be a directory with 'evosnapshot' extension.")
 
        verbosePrint("Using local snapshot\n'\(snapshotURL.relativePath)'")

        let sourceSnapshot = try Snapshot(snapshotURL: snapshotURL, ignorePreviousResults: ignorePreviousResults, extractionDate: extractionDate)

        let jobMetadata = JobMetadata(toolVersion: toolVersion, commit: sourceSnapshot.branchInfo?.commit.sha, extractionDate: sourceSnapshot.snapshotDate)
                
        return ExtractionJob(source: source, output: output, branchInfo: sourceSnapshot.branchInfo, proposalListing: sourceSnapshot.proposalListing, proposalSpecs: sourceSnapshot.proposalSpecs, previousResults: sourceSnapshot.previousResults, expectedResults: sourceSnapshot.expectedResults, forcedExtractionIDs: forcedExtractionIDs, jobMetadata: jobMetadata)
    }
}

// MARK: - Comparison

extension ExtractionJob {
    
    private func compareResultsToExpectedValuesIfPresent(_ results: EvolutionMetadata) {

        guard let expectedResults else {
            return
        }
        
        if results.proposals.count != expectedResults.proposals.count {
            verbosePrint("Extracted proposal count \(results.proposals.count) does not match expected proposal count of \(expectedResults.proposals.count)")
        }
        
        var passingProposals = 0
        var failingProposals = 0
        for (actualResult, expectedResult) in zip(results.proposals, expectedResults.proposals) {
            if actualResult == expectedResult {
                passingProposals += 1
            } else {
                failingProposals += 1
            }
        }
        
        verbosePrint("Comparing to snapshot expected results", terminator: "\n")
        verbosePrint("Passing Proposals:", passingProposals, terminator: "\n")
        verbosePrint("Failing Proposals:", failingProposals)
    }
}

// MARK: - Output

extension ExtractionJob {
    
    private func outputResults(_ results: EvolutionMetadata) throws {
        switch output {
            case .metadataJSON(let outputURL):
                try ExtractionJob.writeEvolutionResultsAsJSON(results: results, outputURL: outputURL)
            case .snapshot(let outputURL):
                try writeSnapshot(results: results, outputURL: outputURL)
            case .validationReport, .none:
                return
        }
    }
    
    private static func writeEvolutionResultsAsJSON(results: EvolutionMetadata, outputURL: URL) throws {
        print("Writing file '\(outputURL.lastPathComponent)' to\n'\(outputURL.absoluteURL.path())'\n")
        
        let jsonData = try results.jsonRepresentation
        
        let directoryURL = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try jsonData.write(to: outputURL)
        
        // Temporarily write not found message to proposals.json file
        let notFoundMessageJSON = """
            {
              "message": "Not Found",
              "reason": "The proposals.json file has been obsoleted and replaced by https://download.swift.org/swift-evolution/v1/evolution.json. See https://forums.swift.org/t/swift-evolution-metadata-transition/71387 for full transition details.",
              "status": "404"
            }
        """
        
        let legacyFormatURL = directoryURL.appending(component: "proposals.json")
        print("Writing file '\(legacyFormatURL.lastPathComponent)' to\n'\(legacyFormatURL.absoluteURL.path())'\n")
        let notFoundMessageData = Data(notFoundMessageJSON.utf8)
        try notFoundMessageData.write(to: legacyFormatURL)
    }
    
    private func writeSnapshot(results: EvolutionMetadata, outputURL: URL) throws {
        try Snapshot.writeSnapshot(job: self, temporarySnapshotDirectory: temporarySnapshotDirectory, temporaryProposalsDirectory: temporaryProposalsDirectory, results: results, outputURL: outputURL)
    }
}

extension EvolutionMetadata {
    var jsonRepresentation: Data {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            let adjustedData = JSONRewriter.applyRewritersToJSONData(rewriters: [JSONRewriter.prettyPrintVersions], data: data)
            return adjustedData
        }
    }
}
