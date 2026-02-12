// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct AuthorExtractor: ValueExtractor {
    private let source: HeaderFieldSource
    init(source: HeaderFieldSource) { self.source = source }
    func extractValue() -> ExtractionResult<[Proposal.Person]> {
        var personExtractor = PersonExtractor(source: source, role: .author)
        return personExtractor.personArray()
    }
}

struct ReviewManagerExtractor: ValueExtractor {
    private let source: HeaderFieldSource
    init(source: HeaderFieldSource) { self.source = source }
    func extractValue() -> ExtractionResult<[Proposal.Person]> {
        var personExtractor = PersonExtractor(source: source, role: .reviewManager)
        return personExtractor.personArray()
    }
}

struct PersonExtractor: MarkupWalker {
    enum Role {
        case author
        case reviewManager
    }

    private var source: HeaderFieldSource
    private var role: Role
    init(source: HeaderFieldSource, role: Role) {
        self.source = source
        self.role = role
    }
    
    private var issues = IssueWrapper()
    private var personList: [Proposal.Person] = []

    mutating func personArray() -> ExtractionResult<[Proposal.Person]> {
        let headerLabels = switch role {
            case .author: ["Author", "Authors"]
            // VALIDATION ENHANCEMENT: Normalize capitalization to 'Review Manager'
            case .reviewManager: ["Review manager", "Review Manager", "Review managers", "Review Managers"]
        }
        if let (_, headerField) = source[headerLabels] {
            visit(headerField)
        }
        
        // VALIDATION ENHANCEMENT: Log a warning if no review manager.  It should be a CI validation error also

        return ExtractionResult(value: personList, warnings: issues.warnings, errors: issues.errors)
    }

    mutating func visitLink(_ link: Link) -> () {
        guard let linkInfo = LinkInfo(link: link) else {
            return
        }
        // VALIDATION ENHANCEMENT: Add 'extra markup error' for review managers
        if !linkInfo.containsTextElement && role == .author {
            issues.reportIssue(.authorsHaveExtraMarkup, source: source)
        }
        
        let destination: String
        if let validatedDestination = linkInfo.gitHubDestination {
            destination = validatedDestination
        } else {
            switch role {
                case .author: issues.reportIssue(.invalidAuthorLink, source: source)
                case .reviewManager: issues.reportIssue(.invalidReviewManagerLink, source: source)
            }
            destination = ""
        }
        let person = Proposal.Person(name: linkInfo.text, link: destination)
        personList.append(person)
    }
    
    // Find plain names after header label (e.g. Authors: ) or as comma-separated list items
    mutating func visitText(_ text: Text) -> () {
        let textString = text.string
        
        if let labelMatch = textString.firstMatch(of: /(.*: |, )([^,]*),?/) {
            if !labelMatch.2.isEmpty {
                //                print("'\(labelMatch.2)'")
                let person = Proposal.Person(name: String(labelMatch.2))
                personList.append(person)
            }
        }
    }
}
