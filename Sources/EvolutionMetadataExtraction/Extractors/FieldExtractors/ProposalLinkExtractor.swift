
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
    
    private var proposalLink: LinkInfo? = nil
    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []
    
    mutating func extractValue(from headerFieldsByLabel: [String : ListItem]) -> ExtractionResult<LinkInfo> {
        if let headerField = headerFieldsByLabel["Proposal"] {
            visit(headerField)
        } else {
            errors.append(ValidationIssue.missingProposalIDLink)
        }
        if let proposalLink {
            
            if !proposalLink.containsTextElement {
                warnings.append(ValidationIssue.proposalIDHasExtraMarkup)
            }
            
            // VALIDATION ENHANCEMENT: To match legacy behavior, if ID has extra markup, the
            // ID is an empty string. An enhancement would be to capture the ID if possible
            if !proposalLink.text.isEmpty {
                
                if proposalLink.text == "SE-0000" {
                    errors.append(ValidationIssue.reservedProposalID)
                }
                
                if !proposalLink.text.contains(/^SE-\d\d\d\d$/) {
                    errors.append(ValidationIssue.proposalIDWrongDigitCount)
                }
                
                // VALIDATION ENHANCEMENT: Once we move from the legacy tool. Remove this.
                // Legacy tool behavior is to fix the error in the json, but leave it as an
                // unreported error in the original proposal.
                //
                // It would be more correct to report the error so it is fixed in the original proposal.
                let baseURI = "https://github.com/apple/swift-evolution/blob/main/proposals/"
                if proposalLink.destination.hasPrefix(baseURI) {
                    self.proposalLink?.destination = proposalLink.destination.replacingOccurrences(of: baseURI, with: "")
                }
                
                // The self-referential link should be relative.
                // VALIDATION ENHANCEMENT: Once we move from the legacy tool. Uncomment this.
                //            if !proposalLink.destination.contains(/^\d\d\d\d-.*\.md$/) {
                //                errors.append(ContentIssue.invalidProposalIDLink)
                //            }
            }
            
        } else {
            errors.append(ValidationIssue.missingProposalIDLink)
        }
        return ExtractionResult(value: proposalLink ?? LinkInfo(text: "", destination: ""), warnings: warnings, errors: errors)
    }
    
    mutating func visitLink(_ link: Link) -> () {
        guard let value = LinkInfo(link: link) else {
            errors.append(ValidationIssue.missingProposalIDLink)
            return
        }
        proposalLink = value
    }
}
