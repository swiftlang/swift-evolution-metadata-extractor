
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
    func extractValue(from headerFieldsByLabel: [String : ListItem]) -> ExtractionResult<[Proposal.Person]> {
        var personExtractor = PersonExtractor(role: .author)
        return personExtractor.personArray(from: headerFieldsByLabel)
    }
}

struct ReviewManagerExtractor: ValueExtractor {
    func extractValue(from headerFieldsByLabel: [String : ListItem]) -> ExtractionResult<[Proposal.Person]> {
        var personExtractor = PersonExtractor(role: .reviewManager)
        return personExtractor.personArray(from: headerFieldsByLabel)
    }
}

struct PersonExtractor: MarkupWalker {
    enum Role {
        case author
        case reviewManager
    }
    
    private var role: Role = .author
    
    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    private var personList: [Proposal.Person] { linkPersonList + plainPersonList }
    private var linkPersonList: [Proposal.Person] = []
    private var plainPersonList: [Proposal.Person] = []
    
    init(role: Role) {
        self.role = role
    }
    
    mutating func personArray(from headerFields: [String : ListItem]) -> ExtractionResult<[Proposal.Person]> {
        var listItem: ListItem? = nil
        let headerLabels = switch role {
        case .author: ["Author", "Authors"]
        case .reviewManager: ["Review manager", "Review Manager"]
        }
        for key in headerLabels {
            if let value = headerFields[key] {
                listItem = value
                break
            }
        }
        if let proposalField = listItem {
            visit(proposalField)
        }
        
        // VALIDATION ENHANCEMENT: Log a warning if no review manager.  It should be a CI validation error also

        return ExtractionResult(value: personList, warnings: warnings, errors: errors)
    }

    mutating func visitLink(_ link: Link) -> () {
        guard let linkInfo = LinkInfo(link: link) else {
            return
        }
        // VALIDATION ENHANCEMENT: Add 'extra markup error' for review managers
        if !linkInfo.containsTextElement && role == .author {
            errors.append(ValidationIssue.authorsHaveExtraMarkup)
        }
        
        // VALIDATION ENHANCEMENT: This error was in the legacy tool, but never triggered for authors due to a bug
        // Once move to new tool happens, validation against previous results is no longer needed.
        // Can re-enable for both person roles
        let person: Proposal.Person
        if role == .reviewManager {
            let destination: String
            if let validatedDestination = linkInfo.gitHubDestination {
                destination = validatedDestination
            } else {
                switch role {
                    case .author: warnings.append(ValidationIssue.invalidAuthorLink)
                    case .reviewManager: warnings.append(ValidationIssue.invalidReviewManagerLink)
                }
                destination = ""
            }
            person = Proposal.Person(name: linkInfo.text, link: destination)
        } else {
            person = Proposal.Person(name: linkInfo.text, link: linkInfo.destination)
        }
        linkPersonList.append(person)
    }

    // Find plain names after header label (e.g. Authors: ) or as comma-separated list items
    mutating func visitText(_ text: Text) -> () {
        let textString = text.string
        
        if let labelMatch = textString.firstMatch(of: /(.*: |, )([^,]*),?/) {
            if !labelMatch.2.isEmpty {
                //                print("'\(labelMatch.2)'")
                let person = Proposal.Person(name: String(labelMatch.2))
                plainPersonList.append(person)
            }
        }
    }
}
