// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

struct Snapshot {
    let sourceURL: URL?
    let destURL: URL?
    var proposalListing: [GitHubContentItem]? = nil // Ad-hoc snapshots may not have these
    var directoryContents: [ProposalSpec]
    var proposalSpecs: [ProposalSpec] = []
    var previousResults: EvolutionMetadata? = nil
    var expectedResults: EvolutionMetadata? = nil
    var branchInfo: GitHubBranch?
    var snapshotDate: Date
     
    let temporarySnapshotDirectory: URL?
    let temporaryProposalsDirectory: URL?
    
    init(sourceURL: URL?, destURL: URL?, proposalListing: [GitHubContentItem]?, directoryContents: [ProposalSpec], proposalSpecs: [ProposalSpec], previousResults: EvolutionMetadata?, expectedResults: EvolutionMetadata?, branchInfo: GitHubBranch?, snapshotDate: Date) {
        self.sourceURL = sourceURL
        self.destURL = destURL
        self.proposalListing = proposalListing
        self.directoryContents = directoryContents
        self.proposalSpecs = proposalSpecs
        self.previousResults = previousResults
        self.expectedResults = expectedResults
        self.branchInfo = branchInfo
        self.snapshotDate = snapshotDate

        if destURL != nil {
            temporarySnapshotDirectory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
            temporaryProposalsDirectory = temporarySnapshotDirectory?.appending(component: "proposals")
        } else {
            temporarySnapshotDirectory = nil
            temporaryProposalsDirectory = nil
        }
    }

    static func makeSnapshot(from snapshotURL: URL, destURL: URL?, ignorePreviousResults: Bool, extractionDate: Date) throws -> Snapshot{
        var proposalListingFound = false
        var previousResultsFound = false
                        
        let branchInfoURL = snapshotURL.appending(component: "source-info.json")
        let proposalListingURL = snapshotURL.appending(component: "proposal-listing.json")
        let previousResultsURL = snapshotURL.appending(component: "previous-results.json")
        let expectedResultsURL = snapshotURL.appending(component: "expected-results.json")
        let proposalDirectoryURL = snapshotURL.appending(component: "proposals")

        let branchInfo = try FileUtilities.decode(GitHubBranch.self, from: branchInfoURL)

        let directoryContents = try FileManager.default.contentsOfDirectory(at: proposalDirectoryURL, includingPropertiesForKeys: nil)
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .filter { $0.pathExtension == "md"}
            .enumerated()
            .map { ProposalSpec(url: $1, sha: "", sortIndex: $0) } // try! SHA1.hexForData(Data(contentsOf: $0)))

        let proposalSpecs: [ProposalSpec]
        let proposalListing: [GitHubContentItem]?
        if let contentItems = try FileUtilities.decode([GitHubContentItem].self, from: proposalListingURL) {
            proposalListing = contentItems
            proposalSpecs = contentItems.enumerated().map { ProposalSpec(url: snapshotURL.appending(path: $1.path), sha: $1.sha, sortIndex: $0) }
            proposalListingFound = true
            if directoryContents.count != proposalSpecs.count {
                print("WARNING: Number of proposals in proposals directory does not match number of proposals in 'proposal-listing.json")
            }
        } else {
            proposalListing = nil
            proposalSpecs = directoryContents
        }
        
        var previousResults: EvolutionMetadata? = nil
        if !ignorePreviousResults {
            if let previous = try FileUtilities.decode(EvolutionMetadata.self, from: previousResultsURL) {
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
        
        return Snapshot(sourceURL: snapshotURL, destURL: destURL, proposalListing: proposalListing, directoryContents: directoryContents, proposalSpecs: proposalSpecs, previousResults: previousResults, expectedResults: expectedResults, branchInfo: branchInfo, snapshotDate: snapshotDate)


        // Expected test file directory structure:
        //
        // proposals/XXXX-proposal-files.md : Directory of proposal markdown files
        // expected-results.json            : Expected results from the source data. If present, will compare at end of run.
        // previous-results.json            : Previous results. If present, will reuse found proposal entries.
        // proposal-listing.json            : Results of GitHub query of proposals directory. Contains proposal SHA values.
        
    }
    
    func writeSnapshot(results: EvolutionMetadata, outputURL: URL) throws {
        
        guard let temporarySnapshotDirectory = temporarySnapshotDirectory, let temporaryProposalsDirectory = temporaryProposalsDirectory else {
            fatalError("When snapshot command is being run temporarySnapshotDirectory should never be nil")
        }

        guard FileManager.default.fileExists(atPath: temporaryProposalsDirectory.path(percentEncoded: false)) else {
            fatalError("Temporary proposals directory should already be created during metadata extraction")
        }
        
        guard let destURL, outputURL == destURL else {
            fatalError("Output URL does not match destination URL")
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
        if let sourceURL = sourceURL {
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

#if os(Linux)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: temporarySnapshotDirectory, to: outputURL)
#else
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: temporarySnapshotDirectory, options: [.usingNewMetadataOnly])
#endif
    }
}
