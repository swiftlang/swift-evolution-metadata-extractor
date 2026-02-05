// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

struct EvolutionMetadataExtractor {
    
    static func extractEvolutionMetadata(for extractionJob: ExtractionJob) async throws -> EvolutionMetadata {
        
        let (filteredProposalSpecs, reusableProposals) = filterProposalSpecs(for: extractionJob)
        
        // If creating a snapshot, write proposal files when fetching.
        // Create a temporary proposals directory to write proposal files into.
        if let temporaryProposalsDirectory = extractionJob.snapshot?.temporaryProposalsDirectory {
            try FileManager.default.createDirectory(at: temporaryProposalsDirectory, withIntermediateDirectories: true)
            
            // If the source is a snapshot, copy reused proposal files to temporary proposals directory
            if let sourceBaseURL = extractionJob.snapshot?.sourceURL {
                for reusableProposal in reusableProposals {
                    let sourceURL = sourceBaseURL.appending(components: "proposals", reusableProposal.proposal.link)
                    let destURL = temporaryProposalsDirectory.appending(component: reusableProposal.proposal.link)
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
        }

        let proposals = await extractAllProposalMetadata(from: filteredProposalSpecs, extractionJob: extractionJob)
        
        verbosePrint("Reused Proposal Count:", reusableProposals.count, terminator: "\n")
        verbosePrint("Processed Proposal Count:", proposals.count)
        
        // Combine and sort reused and newly extracted proposal metadata
        let sortedRecords = (reusableProposals + proposals).sorted(using: SortDescriptor(\.sortIndex))
        let combinedProposals = sortedRecords.map { $0.proposal }
        
        // Add top-level metadata
        
        // Calculate implementation versions
        var implementationVersionSet: Set<String> = []
        for proposal in combinedProposals {
            if case let Proposal.Status.implemented(version) = proposal.status, !version.isEmpty {
                implementationVersionSet.insert(version)
            }
        }
        let implementationVersions =  implementationVersionSet.sorted { $0.compare($1, options: .numeric) == .orderedAscending }
        
        verbosePrint("Implementation Versions:", implementationVersions)
        let formattedExtractionDate = extractionJob.jobMetadata.extractionDate.formatted(.iso8601)

        return EvolutionMetadata(
            creationDate: formattedExtractionDate,
            implementationVersions: implementationVersions,
            proposals: combinedProposals,
            commit: extractionJob.jobMetadata.commit ?? "",
            toolVersion: ToolVersion.version
        )
    }
    
    private static func extractAllProposalMetadata(from proposalSpecs: [ProposalSpec], extractionJob: ExtractionJob) async -> [SortableProposalWrapper] {
        
        await withTaskGroup(of: SortableProposalWrapper.self, returning: [SortableProposalWrapper].self) { taskGroup in
            
            for spec in proposalSpecs {
                taskGroup.addTask { await readAndExtractProposalMetadata(from: spec, proposalDirectoryURL: extractionJob.snapshot?.temporaryProposalsDirectory, extractionDate: extractionJob.jobMetadata.extractionDate) }
            }
            
            var proposals: [SortableProposalWrapper] = []
            for await result in taskGroup {
                proposals.append(result)
            }
            
            return proposals
        }

    }
    
    private static func readAndExtractProposalMetadata(from proposalSpec: ProposalSpec, proposalDirectoryURL: URL?, extractionDate: Date) async -> SortableProposalWrapper {
        do {
            let markdownString: String
            if proposalSpec.url.isFileURL {
                markdownString = try String(contentsOf: proposalSpec.url, encoding: .utf8)
            } else {
                markdownString = try await GitHubFetcher.fetchProposalContents(from: proposalSpec.url)
            }
            
            if let proposalDirectoryURL {
                let proposalFileURL = proposalDirectoryURL.appending(component: proposalSpec.filename)
                let data = Data(markdownString.utf8)
                try data.write(to: proposalFileURL)
            }

            let proposal = ProposalMetadataExtractor.extractProposalMetadata(from: markdownString, proposalSpec: proposalSpec, extractionDate: extractionDate)
            
            // For proposals that fail proposal link / id extraction, provides a way to identify the problem file in validation reports
            // When activated, be sure to set the link back to empty string post-validation report
//            if parsedProposal.link.isEmpty { parsedProposal.link = proposalSpec.name }
            
            // VALIDATION ENHANCEMENT: Validate that the 'link' value matches the filename
            // VALIDATION ENHANCEMENT: Note that items in Malformed test would need to be updated, since their filename matches the problem exhibited
            
            return SortableProposalWrapper(proposal: proposal, sortIndex: proposalSpec.sortIndex)

        } catch {
            print(error)
            return SortableProposalWrapper(proposal: Proposal(errors:[.proposalContainsNoContent]), sortIndex: proposalSpec.sortIndex)
        }
    }
    
    static func filterProposalSpecs(for extractionJob: ExtractionJob) -> ([ProposalSpec], [SortableProposalWrapper]) {
        
        // If there are no previous results, there can be no reuse. Return early.
        guard let previousResults = extractionJob.previousResults else {
            return (extractionJob.proposalSpecs, [SortableProposalWrapper]())
        }
        
        let sortablePreviousResults = previousResults.proposals
            .enumerated()
            .map { SortableProposalWrapper(proposal: $1, sortIndex: $0)}
        
        var parsedProposalsById = sortablePreviousResults.reduce(into: [String:SortableProposalWrapper]()) { $0[$1.id] = $1 }
        var reusableProposals: [SortableProposalWrapper] = []
        var deletedProposals: [SortableProposalWrapper] = []

        let needsParsing = extractionJob.proposalSpecs.reduce(into: [ProposalSpec]()) { partialResult, githubProposal in
            if let parsedProposal = parsedProposalsById.removeValue(forKey: githubProposal.id) {
                if parsedProposal.sha == githubProposal.sha && !extractionJob.forcedExtractionIDs.contains(githubProposal.id) {
                    // This assertion tests the assumption that proposals with the same ID will have same sort index
                    // In the repository, because proposals are only added and never change sort order
                    // In snapshots because they are static
                    assert(parsedProposal.sortIndex == githubProposal.sortIndex)
                    reusableProposals.append(parsedProposal)
                }
                else {
                    partialResult.append(githubProposal)
                }
            } else {
                partialResult.append(githubProposal)
            }
        }
        
        // Remove deleted proposals from reusable proposals
        for id in parsedProposalsById.keys {
            reusableProposals.removeAll { $0.id == id }
        }
        deletedProposals.append(contentsOf: parsedProposalsById.values)
        
        if needsParsing.count == 0 && deletedProposals.count == 0 {
            print("No proposals require extraction. Using previously extracted results.\n")
        }

        return (needsParsing, reusableProposals)
    }
}

/// A `ProposalSpec` contains the information necessary to extract and generate the metadata for a proposal.
///
/// Each `ProposalSpec` contains the URL to access the contents of the proposal and the SHA value of the proposal.
/// It also includes convenience properties for the filename and proposal ID.
///
/// The listing of proposals to be processed may come from a GitHub proposal listing or scanning the contents of a directory.
///
struct ProposalSpec: Sendable {
    let project: Project
    let url: URL
    let sha: String
    let sortIndex: Int
    var id: String { "SE-" + url.lastPathComponent.prefix(4) }
    var filename: String { url.lastPathComponent }
    
    init(project: Project, url: URL, sha: String, sortIndex: Int) {
        self.project = project
        self.url = url
        self.sha = sha
        self.sortIndex = sortIndex
    }
}

/// Wrapper to ensure malformed proposals can be sorted correctly
///
/// Proposals are sorted by proposal ID. Malformed markdown may make it impossible to extract the ID.
/// The wrapper ensures sort order is maintained.
///
struct SortableProposalWrapper {
    let proposal: Proposal
    let sortIndex: Int
    var id: String { proposal.id }
    var sha: String { proposal.sha }
}
