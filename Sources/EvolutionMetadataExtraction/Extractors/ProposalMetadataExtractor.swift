
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import Markdown
import EvolutionMetadataModel

struct ProposalMetadataExtractor {
    
    /// Extracts the metadata from a Swift Evolution proposal
    /// - Parameters:
    ///   - markdown: The markdown string of a Swift Evolution proposal
    ///   - proposalSpec: Proposal specification including the proposal ID
    ///   - extractionDate: Extraction date used to determine expired review periods
    /// - Returns: The extracted proposal metadata
    static func extractProposalMetadata(from markdown: String, proposalSpec: ProposalSpec, extractionDate: Date) -> Proposal {
                
        var proposal = Proposal()
        proposal.sha = proposalSpec.sha
        
        var warnings: [Proposal.Issue] = []
        var errors: [Proposal.Issue] = []
        
        func extractValue<T: ValueExtractor>(from source: T.Source, with extractorType: T.Type) -> T.ResultValue? {
            var extractor = extractorType.init()
            let result = extractor.extractValue(from: source)
            warnings.append(contentsOf: result.warnings)
            errors.append(contentsOf: result.errors)
            return result.value
        }
        
        let document = Document(parsing: markdown, options: [.disableSmartOpts])
        
        guard !document.isEmpty else {
            proposal.errors = [.emptyMarkdownFile]
            return proposal
        }
        
        // VALIDATION ENHANCEMENT: Currently no error or warning reported if missing title or summary.
        // Change to if lets to detect missing values and report.
        proposal.title = extractValue(from: document, with: TitleExtractor.self) ?? ""
        proposal.summary = extractValue(from: document, with: SummaryExtractor.self) ?? ""
        
        if let headerFieldsByLabel = extractValue(from: document, with: HeaderFieldExtractor.self) {
            
            let proposalLink = extractValue(from: headerFieldsByLabel, with: ProposalLinkExtractor.self)
            proposal.id = proposalLink?.text ?? ""
            proposal.link = proposalLink?.destination ?? ""
            /* VALIDATION ENHANCEMENT: Probably also want to validate that the destination link matches the passed-in filename and the id matches the proposalID field */
            
            if let authors = extractValue(from: headerFieldsByLabel, with: AuthorExtractor.self), !authors.isEmpty {
                proposal.authors = authors
            } else {
                errors.append(.missingAuthors)
            }
            
            if let reviewManagers = extractValue(from: headerFieldsByLabel, with: ReviewManagerExtractor.self), !reviewManagers.isEmpty {
                proposal.reviewManager = reviewManagers.first!
                proposal.reviewManagers = reviewManagers
            } else {
                warnings.append(.missingReviewManagers)
            }
            
            proposal.upcomingFeatureFlag = extractValue(from: headerFieldsByLabel, with: UpcomingFeatureFlagExtractor.self)
            proposal.previousProposalIDs = extractValue(from: headerFieldsByLabel, with: PreviousProposalExtractor.self)
            proposal.trackingBugs = extractValue(from: headerFieldsByLabel, with: TrackingBugExtractor.self)
            proposal.implementation = extractValue(from: headerFieldsByLabel, with: ImplementationExtractor.self)
            
            if let discussions = extractValue(from: (headerFieldsByLabel, proposalSpec.id), with: DiscussionExtractor.self) {
                proposal.discussions = discussions
            } else {
                errors.append(.missingReviewField)
            }
            
            if let status = extractValue(from: (headerFieldsByLabel, extractionDate), with: StatusExtractor.self) {
                if case .implemented(let version) = status, version == "none" {
                    // VALIDATION ENHANCEMENT: Figure out a better way to special case the missing version strings for these proposals
                    // VALIDATION ENHANCEMENT: Possibly just add version strings to the actual proposals
                    if proposalSpec.id == "SE-0264" || proposalSpec.id == "SE-0110" {
                        proposal.status = .implemented(version: "")
                    } else {
                        // VALIDATION ENHANCEMENT: This *should* be a validation error
                        proposal.status = .implemented(version: "")
                    }
                } else {
                    proposal.status = status
                }
            } else {
                // VALIDATION ENHANCEMENT: Report an error
                proposal.status = .statusExtractionFailed
            }
        } else {
            errors.append(.missingMetadataFields)
        }
        
        // Add warnings and errors if present
        if !warnings.isEmpty { proposal.warnings = warnings }
        if !errors.isEmpty { proposal.errors = errors }

        return proposal
    }
}

protocol ValueExtractor {
    associatedtype Source
    associatedtype ResultValue
    mutating func extractValue(from source: Source) -> ExtractionResult<ResultValue>
    init()
}

/* Returns an optional value and parsing or validation warnings and errors.
 Unlike the standard library `Result` type, this returns a value plus content warnings and errors. */
struct ExtractionResult<T> {
    var value: T?
    var warnings: [Proposal.Issue] = []
    var errors: [Proposal.Issue] = []
}


/* The approach is for the extractors to return nil if no value is found.
    It is up to the caller to determine the appropriate thing to do with a missing parsed value
 for example, include an empty string, etc.
 */


// For simple links, extracts the value of a single text child and destination string
// Returns nil if this is not a simple link
// The caller should return a validaton error if appropriate

// A struct for passing around parsed link information
struct LinkInfo {
    var text: String = ""
    var destination: String
    var containsTextElement: Bool = false
    
    init(text: String, destination: String) {
        self.text = text
        self.destination = destination
    }
    
    init?(link: Link) { // PlainTextConvertibleMarkup
        guard let plainTextElement = link.child(at: 0) as? any PlainTextConvertibleMarkup,
              let destination = link.destination else {
            return nil
        }
        // VALIDATION ENHANCEMENT: Check for additional children / more complex markup
        
        // VALIDATION ENHANCEMENT: Use 'plainText' to extract value if there is a single PlainTextConvertibleMarkup child.
        if let text = plainTextElement as? Text {
            containsTextElement = true
            self.text = text.string
        }
        self.destination = destination
    }
    
    var gitHubDestination: String? {
        if destination.starts(with: "https://github.com") {
            return destination
        } else {
            return nil
        }
    }
    
    var swiftForumsDestination: String? {
        if destination.starts(with: "https://forums.swift.org") {
            return destination
        } else {
            return nil
        }
    }
}



