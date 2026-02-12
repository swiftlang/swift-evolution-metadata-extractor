// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct ProposalLinkExtractor: MarkupWalker, ValueExtractor {
    
    private var source: HeaderFieldSource
    init(source: HeaderFieldSource) { self.source = source }

    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    private var proposalLink: LinkInfo? = nil

    mutating func extractValue() -> ExtractionResult<LinkInfo> {
        if let headerField = source["Proposal"] {
            visit(headerField)
        } else {
            errors.append(.missingProposalField)
        }
        if let proposalLink {
            
            if !proposalLink.containsTextElement {
                warnings.append(.proposalIDHasExtraMarkup)
            }
            
            // VALIDATION ENHANCEMENT: To match legacy behavior, if ID has extra markup, the
            // ID is an empty string. An enhancement would be to capture the ID if possible
            if !proposalLink.text.isEmpty {
                
                if proposalLink.text == "SE-0000" {
                    errors.append(.reservedProposalID)
                }
                
                if !proposalLink.text.contains(source.project.proposalRegex) {
                    self.proposalLink?.destination = "" // Do not include an incorrect destination
                    errors.append(.proposalIDWrongDigitCount)
                }

                // The link should be relative and contain the correct number of digits.
                if !proposalLink.destination.contains(/^\d\d\d\d-.*\.md$/) {
                    self.proposalLink?.destination = "" // Do not include an incorrect destination
                    errors.append(Proposal.Issue.invalidProposalIDLink)
                }
            }
            
        } else {
            errors.append(.missingProposalIDLink)
        }
        return ExtractionResult(value: proposalLink ?? LinkInfo(text: "", destination: ""), warnings: warnings, errors: errors)
    }
    
    mutating func visitLink(_ link: Link) -> () {
        proposalLink = LinkInfo(link: link)
    }
}
