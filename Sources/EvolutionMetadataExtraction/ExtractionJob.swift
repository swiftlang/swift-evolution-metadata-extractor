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
        case files([URL])
    }
    
    public enum Output: Sendable, Codable, Equatable {
        case metadataJSON(URL)
        case snapshot(URL)
        case validationReport(URL)
        case none
        
        var snapshotURL: URL? {
            if case let .snapshot(url) = self { url }
            else { nil }
        }
    }
    
    struct JobMetadata: Sendable, Codable, Equatable {
        let commit: String?
        let extractionDate: Date
    }

    let proposalSpecs: [ProposalSpec]
    let previousResults: EvolutionMetadata?
    let forcedExtractionIDs: [String]
    let jobMetadata: JobMetadata
    let output: Output
    let snapshot: Snapshot?

    private init(output: Output, snapshot: Snapshot?, proposalSpecs: [ProposalSpec], previousResults: EvolutionMetadata?, forcedExtractionIDs: [String], jobMetadata: JobMetadata) {
        self.proposalSpecs = proposalSpecs
        self.previousResults = previousResults
        self.forcedExtractionIDs = forcedExtractionIDs
        self.output = output
        self.snapshot = snapshot
        self.jobMetadata = jobMetadata
    }
    
    public func run() async throws {
        // Extract Metadata
        let evolutionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: self)
        
        // Compare results against expected results, if extraction job has them
        compareResultsToExpectedValuesIfPresent(evolutionMetadata)
        
        // Output Results
        try outputResults(evolutionMetadata)

    }
    
    public static func makeExtractionJob(from source: Source, output: Output, ignorePreviousResults: Bool = false, forcedExtractionIDs: [String] = [], extractionDate: Date = Date()) async throws -> ExtractionJob {
        switch source {
            case .network:
                try await makeNetworkExtractionJob(output: output, ignorePreviousResults: ignorePreviousResults, forcedExtractionIDs: forcedExtractionIDs, extractionDate: extractionDate)
            case .snapshot(let snapshotURL):
                try await makeSnapshotExtractionJob(snapshotURL: snapshotURL, output: output, ignorePreviousResults: ignorePreviousResults, forcedExtractionIDs: forcedExtractionIDs, extractionDate: extractionDate)
            case .files(let fileURLs):
                try makeFilesExtractionJob(fileURLs: fileURLs, output: output, ignorePreviousResults: ignorePreviousResults, forcedExtractionIDs: forcedExtractionIDs, extractionDate: extractionDate)
        }
    }
}

// MARK: - Gather Job Requirements & Create

extension ExtractionJob {
    
    private static func makeNetworkExtractionJob(output: Output, ignorePreviousResults: Bool, forcedExtractionIDs: [String], extractionDate: Date) async throws -> ExtractionJob {
        
        async let previousResults = previousResults(from: PreviousResultsFetcher.previousResultsURL, ignorePreviousResults: ignorePreviousResults)
        let mainBranchInfo = try await GitHubFetcher.fetchMainBranch()
        let sha = mainBranchInfo.commit.sha
        let proposalContentItems = try await GitHubFetcher.fetchProposalContentItems(for: sha)

        // The proposals/ directory may have subdirectories for
        // proposals from specific workgroups. For now, proposals
        // in those subdirectories are filtered out of this proposal
        // specs array.
        let proposalSpecs = proposalContentItems.enumerated().compactMap {
            $1.proposalSpec(sortIndex: $0)
        }

        let jobMetadata = JobMetadata(commit: sha, extractionDate: extractionDate)

        let snapshot: Snapshot?
        if case let .snapshot(destURL) = output {
            snapshot = Snapshot(sourceURL: nil, destURL: destURL, proposalListing: proposalContentItems, directoryContents: [], proposalSpecs: [], previousResults: nil, expectedResults: nil, branchInfo: mainBranchInfo, snapshotDate: extractionDate)
        } else {
            snapshot = nil
        }

        return ExtractionJob(output: output, snapshot: snapshot, proposalSpecs: proposalSpecs, previousResults: try await previousResults, forcedExtractionIDs: forcedExtractionIDs, jobMetadata: jobMetadata)
    }
    
    private static func makeSnapshotExtractionJob(snapshotURL: URL, output: Output, ignorePreviousResults: Bool, forcedExtractionIDs: [String], extractionDate: Date) async throws -> ExtractionJob {

        // Argument validation should ensure correct values. Assert to catch problems in usage in tests.
        assert(snapshotURL.pathExtension == "evosnapshot", "Snapshot URL must be a directory with 'evosnapshot' extension.")
 
        verbosePrint("Using local snapshot\n'\(snapshotURL.relativePath)'")

        let sourceSnapshot = try await Snapshot.makeSnapshot(from: snapshotURL, destURL: output.snapshotURL, ignorePreviousResults: ignorePreviousResults, extractionDate: extractionDate)

        let jobMetadata = JobMetadata(commit: sourceSnapshot.branchInfo?.commit.sha, extractionDate: sourceSnapshot.snapshotDate)
                
        // Always use sourceSnapshot, its values are used in tests
        return ExtractionJob(output: output, snapshot: sourceSnapshot, proposalSpecs: sourceSnapshot.proposalSpecs, previousResults: sourceSnapshot.previousResults, forcedExtractionIDs: forcedExtractionIDs, jobMetadata: jobMetadata)
    }

    private static func makeFilesExtractionJob(fileURLs: [URL], output: Output, ignorePreviousResults: Bool, forcedExtractionIDs: [String], extractionDate: Date) throws -> ExtractionJob {
        
        // Argument validation should ensure correct values. Assert to catch problems in usage in tests.
        assert(ignorePreviousResults == true && forcedExtractionIDs.isEmpty, "Extraction from a file URLs always ignores previous results and performs a full extraction")
        
        let proposalSpecs = fileURLs
            .sorted(using: SortDescriptor(\URL.lastPathComponent, order: .forward))
            .enumerated()
            .map { ProposalSpec(url: $1, sha: "", sortIndex: $0) }

        let jobMetadata = JobMetadata(commit: "", extractionDate: extractionDate)

        let snapshot: Snapshot?
        if case let .snapshot(destURL) = output {
            snapshot = Snapshot(sourceURL: nil, destURL: destURL, proposalListing: nil, directoryContents: [], proposalSpecs: [], previousResults: nil, expectedResults: nil, branchInfo: nil, snapshotDate: extractionDate)
        } else {
            snapshot = nil
        }

        return ExtractionJob(output: output, snapshot: snapshot, proposalSpecs: proposalSpecs, previousResults: nil, forcedExtractionIDs: forcedExtractionIDs, jobMetadata: jobMetadata)
    }

    static func previousResults(from url: URL, ignorePreviousResults: Bool) async throws -> EvolutionMetadata? {
        if ignorePreviousResults { return nil }

        let data: Data?
        if url.isFileURL {
            data = try FileUtilities.data(from: url)
        } else {
            data = try await PreviousResultsFetcher.fetchPreviousResultsData(url: url)
        }

        guard let data else { return nil }

        do {
            let decoder = JSONDecoder()
            let previousResults = try decoder.decode(EvolutionMetadata.self, from: data)
            return previousResults.hasCurrentMetadataVersions ? previousResults : nil
        } catch {
            print("Unable to decode \(EvolutionMetadata.self) from:")
            print(String(decoding: data, as: UTF8.self))
            throw error
        }
    }
}

// MARK: - Comparison

extension ExtractionJob {
    
    private func compareResultsToExpectedValuesIfPresent(_ results: EvolutionMetadata) {

        guard let expectedResults = snapshot?.expectedResults else {
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
            case .validationReport(let outputURL):
                try ExtractionJob.writeValidationReport(results: results, outputURL: outputURL)
            case .none:
                return
        }
    }
    
    private static func writeEvolutionResultsAsJSON(results: EvolutionMetadata, outputURL: URL) throws {
        print("Writing file '\(outputURL.lastPathComponent)' to\n'\(outputURL.absoluteURL.path())'\n")

        let jsonData = try results.jsonRepresentation

        if outputURL.isStandardOutURL {
            FileHandle.standardOutput.write(jsonData)
        } else {
            let directoryURL = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try jsonData.write(to: outputURL)
        }
    }
    
    private func writeSnapshot(results: EvolutionMetadata, outputURL: URL) throws {
        guard let snapshot else { fatalError("Cannot write snapshot. Snapshot is missing.") }
        guard outputURL != URL.standardOutURL else { fatalError("Cannot write snapshot to stdout.") }
        try snapshot.writeSnapshot(results: results, outputURL: outputURL)
    }

    private static func writeValidationReport(results: EvolutionMetadata, outputURL: URL) throws {

        let report = results.validationReport

        if outputURL.isStandardOutURL {
            print(report)
        } else {
            let data = Data(report.utf8)
            let directoryURL = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try data.write(to: outputURL)
        }
        
        if results.hasErrors {
            try exitWithFailure()
        }
    }
}
