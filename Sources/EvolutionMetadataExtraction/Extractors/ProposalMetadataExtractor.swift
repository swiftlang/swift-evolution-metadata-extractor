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

        var issues = IssueWrapper()
        var proposal = Proposal()
        proposal.sha = proposalSpec.sha

        func extractValue<T: ValueExtractor>(from source: T.Source, with extractorType: T.Type) -> T.ResultValue? {
            var extractor = extractorType.init(source: source)
            let result = extractor.extractValue()
            issues.append(errors: result.errors, warnings: result.warnings)
            return result.value
        }
        
        let document = Document(parsing: markdown, options: [.disableSmartOpts])
        let documentSource = DocumentSource(proposalSpec: proposalSpec, document: document)
        
        guard !document.isEmpty else {
            proposal.errors = [.emptyMarkdownFile]
            return proposal
        }
        
        // VALIDATION ENHANCEMENT: Currently no error or warning reported if missing title or summary.
        // Change to if lets to detect missing values and report.
        proposal.title = extractValue(from: documentSource, with: TitleExtractor.self) ?? ""
        proposal.summary = extractValue(from: documentSource, with: SummaryExtractor.self) ?? ""
        
        if let headerFieldsByLabel = extractValue(from: documentSource, with: HeaderFieldExtractor.self) {
            let headerFieldsSource = HeaderFieldSource(proposalSpec: proposalSpec, headerFieldsByLabel: headerFieldsByLabel)

            let proposalLink = extractValue(from: headerFieldsSource, with: ProposalLinkExtractor.self)
            proposal.id = proposalLink?.text ?? ""
            proposal.link = proposalLink?.destination ?? ""
            /* VALIDATION ENHANCEMENT: Probably also want to validate that the destination link matches the passed-in filename and the id matches the proposalID field */
            
            if let authors = extractValue(from: headerFieldsSource, with: AuthorExtractor.self), !authors.isEmpty {
                proposal.authors = authors
            } else {
                issues.reportIssue(.missingAuthors, source: headerFieldsSource)
            }
            
            if let reviewManagers = extractValue(from: headerFieldsSource, with: ReviewManagerExtractor.self), !reviewManagers.isEmpty {
                proposal.reviewManagers = reviewManagers
            } else {
                issues.reportIssue(.missingReviewManagers, source: headerFieldsSource)
            }
            
            proposal.upcomingFeatureFlag = extractValue(from: headerFieldsSource, with: UpcomingFeatureFlagExtractor.self)
            proposal.previousProposalIDs = extractValue(from: headerFieldsSource, with: PreviousProposalExtractor.self)
            proposal.trackingBugs = extractValue(from: headerFieldsSource, with: TrackingBugExtractor.self)
            proposal.implementation = extractValue(from: headerFieldsSource, with: ImplementationExtractor.self)
            
            if let discussions = extractValue(from: headerFieldsSource, with: DiscussionExtractor.self) {
                proposal.discussions = discussions
            } else {
                issues.reportIssue(.missingReviewField, source: headerFieldsSource)
            }
            
            if let status = extractValue(from: (headerFieldsSource, extractionDate), with: StatusExtractor.self) {
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
            issues.reportIssue(.missingMetadataFields, source: documentSource)
        }
        
        // Add warnings and errors to proposal if present
        if !issues.warnings.isEmpty { proposal.warnings = issues.warnings }
        if !issues.errors.isEmpty { proposal.errors = issues.errors }

        return proposal
    }
}

protocol ValueExtractor {
    associatedtype Source
    associatedtype ResultValue
    init(source: Source)
    mutating func extractValue() -> ExtractionResult<ResultValue>
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

// Protocol and structs to encapsulate source and issue information for extractors

struct IssueWrapper {
    private(set) var errors: [Proposal.Issue] = []
    private(set) var warnings: [Proposal.Issue] = []
    mutating func reportIssue<Source: IssueSource>(_ issue: Proposal.Issue, source: Source) {
        if let exclusions = source.project.validationExemptions[issue.code],
           exclusions.contains(source.proposalNumber) { return }
        else {
            switch issue.kind {
                case .error: errors.append(issue)
                case .warning: warnings.append(issue)
            }
        }
    }
    mutating func append(errors: [Proposal.Issue], warnings: [Proposal.Issue]) {
        self.errors.append(contentsOf: errors)
        self.warnings.append(contentsOf: warnings)
    }
}

protocol IssueSource {
    var project: Project { get }
    var proposalNumber: Int { get }
}

struct DocumentSource: IssueSource {
    private let proposalSpec: ProposalSpec
    let document: Document
    var project: Project { proposalSpec.project }
    var proposalNumber: Int { proposalSpec.number }
    init(proposalSpec: ProposalSpec, document: Document) {
        self.proposalSpec = proposalSpec
        self.document = document
    }
}

struct HeaderFieldSource: IssueSource {
    let proposalSpec: ProposalSpec
    let headerFieldsByLabel: [String : ListItem]
    var project: Project { proposalSpec.project }
    var proposalNumber: Int { proposalSpec.number }
    subscript(key: String) -> ListItem? { headerFieldsByLabel[key] }
    subscript(key: [String]) -> (key: String, value: ListItem)? { headerFieldsByLabel[key] }
    subscript(key: String...) -> (key: String, value: ListItem)? { headerFieldsByLabel[key] }
    init(proposalSpec: ProposalSpec, headerFieldsByLabel: [String : ListItem]) {
        self.proposalSpec = proposalSpec
        self.headerFieldsByLabel = headerFieldsByLabel
    }
}




