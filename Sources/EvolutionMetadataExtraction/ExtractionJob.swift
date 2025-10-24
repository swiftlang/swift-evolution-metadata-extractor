
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
    
    let source: Source
    let branchInfo: GitHubBranch?
    let proposalListing: [GitHubContentItem]? // Ad-hoc snapshots may not have these
    let proposalSpecs: [ProposalSpec]
    let previousResults: [Proposal]
    let expectedResults: EvolutionMetadata?
    let forcedExtractionIDs: [String]
    let toolVersion: String
    let extractionDate: Date
    let output: Output
    let temporarySnapshotDirectory: URL?
    var temporaryProposalsDirectory: URL? { temporarySnapshotDirectory?.appending(component: "proposals") }

    private init(source: Source, output: Output, branchInfo: GitHubBranch? = nil, proposalListing: [GitHubContentItem]?, proposalSpecs: [ProposalSpec], previousResults: [Proposal], expectedResults: EvolutionMetadata?, forcedExtractionIDs: [String], toolVersion: String, extractionDate: Date = Date()) {
        self.source = source
        self.branchInfo = branchInfo
        self.proposalListing = proposalListing
        self.proposalSpecs = proposalSpecs
        self.previousResults = previousResults
        self.expectedResults = expectedResults
        self.forcedExtractionIDs = forcedExtractionIDs
        self.toolVersion = toolVersion
        self.extractionDate = extractionDate
        self.output = output
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
        
        async let previousResults = ignorePreviousResults ? [] : PreviousResultsFetcher.fetchPreviousResults()
        
        let mainBranchInfo = try await GitHubFetcher.fetchMainBranch()
        let proposalContentItems = try await GitHubFetcher.fetchProposalContentItems(for: mainBranchInfo.commit.sha)

        // The proposals/ directory may have subdirectories for
        // proposals from specific workgroups. For now, proposals
        // in those subdirectories are filtered out of this proposal
        // specs array.
        let proposalSpecs = proposalContentItems.enumerated().compactMap {
            $1.proposalSpec(sortIndex: $0)
        }

        return ExtractionJob(source: source, output: output, branchInfo: mainBranchInfo, proposalListing: proposalContentItems, proposalSpecs: proposalSpecs, previousResults: try await previousResults, expectedResults: nil, forcedExtractionIDs: forcedExtractionIDs, toolVersion: toolVersion, extractionDate: extractionDate)
    }
    
    private static func makeSnapshotExtractionJob(source: Source, output: Output, ignorePreviousResults: Bool, forcedExtractionIDs: [String], toolVersion: String, extractionDate: Date) throws -> ExtractionJob {
        
        guard case let .snapshot(snapshotURL) = source else {
            fatalError("makeSnapshotExtractionJob() requires snapshot source")
        }
        
        // Argument validation should ensure correct values. Assert to catch problems in usage in tests.
        assert(snapshotURL.pathExtension == "evosnapshot", "Snapshot URL must be a directory with 'evosnapshot' extension.")
 
        verbosePrint("Using local snapshot\n'\(snapshotURL.relativePath)'")
        var proposalListingFound = false
        var previousResultsFound = false
                        
        let branchInfoURL = snapshotURL.appending(component: "source-info.json")
        let proposalListingURL = snapshotURL.appending(component: "proposal-listing.json")
        let previousResultsURL = snapshotURL.appending(component: "previous-results.json")
        let expectedResultsURL = snapshotURL.appending(component: "expected-results.json")
        let proposalDirectoryURL = snapshotURL.appending(component: "proposals")

        var proposalListing: [GitHubContentItem]? = nil
        var directoryContents: [ProposalSpec]
        var proposalSpecs: [ProposalSpec] = []
        var previousResults: [Proposal] = []
        
        let branchInfo = try FileUtilities.decode(GitHubBranch.self, from: branchInfoURL)
        
        directoryContents = try FileManager.default.contentsOfDirectory(at: proposalDirectoryURL, includingPropertiesForKeys: nil)
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .filter { $0.pathExtension == "md"}
            .enumerated()
            .map { ProposalSpec(url: $1, sha: "", sortIndex: $0) } // try! SHA1.hexForData(Data(contentsOf: $0)))

        if let contentItems = try FileUtilities.decode([GitHubContentItem].self, from: proposalListingURL) {
            proposalListing = contentItems
            proposalSpecs = contentItems.enumerated().map { ProposalSpec(url: snapshotURL.appending(path: $1.path), sha: $1.sha, sortIndex: $0) }
            proposalListingFound = true
            if directoryContents.count != proposalSpecs.count {
                print("WARNING: Number of proposals in proposals directory does not match number of proposals in 'proposal-listing.json")
            }
        } else {
            proposalSpecs = directoryContents
        }
        
        if !ignorePreviousResults {
            if let previous = try FileUtilities.decode([Proposal].self, from: previousResultsURL) {
                previousResults = previous
                previousResultsFound = true
            }
        }
        
        let expectedResults = try FileUtilities.decode(EvolutionMetadata.self, from: expectedResultsURL)

        // If expected results has a non-empty creation date string, use that as the extraction date
        // Note that ad-hoc snapshots will potentially have an empty creation date string
        let snapshotDate: Date
        if let dateString = expectedResults?.creationDate, !dateString.isEmpty {
            snapshotDate = try Date(dateString, strategy: .iso8601)
        } else {
            snapshotDate = extractionDate
        }
                    
        print(  """
                    proposal-listing.json found? \(proposalListingFound)
                    \(proposalListingFound ? "Will" : "Will not") use listing for proposal list and SHAs
                    
                    previous-results.json found? \(previousResultsFound)
                    \(previousResultsFound ? "Will use previous results unless --force-extract option is used" :
                       "Will extract values from all proposals")
                    
                    Proposal count: \(proposalSpecs.count)
                    """)
        
        // Expected test file directory structure:
        //
        // proposals/XXXX-proposal-files.md : Directory of proposal markdown files
        // expected-results.json            : Expected results from the source data. If present, will compare at end of run.
        // previous-results.json            : Previous results. If present, will reuse found proposal entries.
        // proposal-listing.json            : Results of GitHub query of proposals directory. Contains proposal SHA values.
        
        return ExtractionJob(source: source, output: output, branchInfo: branchInfo, proposalListing: proposalListing, proposalSpecs: proposalSpecs, previousResults: previousResults, expectedResults: expectedResults, forcedExtractionIDs: forcedExtractionIDs, toolVersion: toolVersion, extractionDate: snapshotDate)
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

        guard let temporarySnapshotDirectory, let temporaryProposalsDirectory else {
            fatalError("When snapshot command is being run temporarySnapshotDirectory should never be nil")
        }

        guard FileManager.default.fileExists(atPath: temporaryProposalsDirectory.path(percentEncoded: false)) else {
            fatalError("Temporary proposals directory should already be created during metadata extraction")
        }
        var addedFilenames: Set<String> = ["proposals"] // Guard statement checks that 'proposals' is present
        
        print("Writing snapshot '\(outputURL.lastPathComponent)' to '\(outputURL.absoluteURL.path())'\n")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        try FileManager.default.createDirectory(at: temporarySnapshotDirectory, withIntermediateDirectories: true)

        if let branchInfo {
            let branchInfoData = try encoder.encode(branchInfo)
            let branchInfoURL = temporarySnapshotDirectory.appending(component: "source-info.json")
            try branchInfoData.write(to: branchInfoURL)
            addedFilenames.insert("source-info.json")
        }
        
        if let proposalListing, !proposalListing.isEmpty {
            let proposalListingData = try encoder.encode(proposalListing)
            let proposalListingURL = temporarySnapshotDirectory.appending(component: "proposal-listing.json")
            try proposalListingData.write(to: proposalListingURL)
            addedFilenames.insert("proposal-listing.json")
        }

        let expectedResultsData = try results.jsonRepresentation
        let expectedResultsURL = temporarySnapshotDirectory.appending(component: "expected-results.json")
        try expectedResultsData.write(to: expectedResultsURL)
        addedFilenames.insert("expected-results.json")

        // If the source is a snapshot, make sure any additional ad-hoc files, such as READMEs are copied to the new snapshot
        if case let .snapshot(sourceURL) = source {
            for srcURL in try FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) {
                if !addedFilenames.contains(srcURL.lastPathComponent) {
                    let dstURL = temporarySnapshotDirectory.appending(component: srcURL.lastPathComponent)
                    try FileManager.default.copyItem(at: srcURL, to: dstURL)
                } else {
                    addedFilenames.remove(srcURL.lastPathComponent)
                }
            }
            guard addedFilenames.isEmpty else { fatalError("Not all files copied: \(addedFilenames)") }
        }

        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: temporarySnapshotDirectory, options: [.usingNewMetadataOnly])
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
