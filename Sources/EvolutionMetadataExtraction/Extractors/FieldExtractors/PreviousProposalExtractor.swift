// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct PreviousProposalExtractor: MarkupWalker, ValueExtractor {
    
    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []
    
    private var previousProposalIDs: [String]? {
        _previousProposalIDs.isEmpty ? nil : _previousProposalIDs
    }
    private var _previousProposalIDs: [String] = []
    
    mutating func extractValue(from src: HeaderFieldSource) -> ExtractionResult<[String]> {
        
        if let prevPropField = src.headerFieldsByLabel[["Previous Proposal", "Previous Proposals"]] {
            visit(prevPropField.value)
            
            // validate that if the header field is here at least one proposal ID was found
            if _previousProposalIDs.isEmpty {
                errors.append(.previousProposalIDsExtractionFailure)
            }
        }
        
        return ExtractionResult(value: previousProposalIDs, warnings: warnings, errors: errors)
    }
    
    mutating func visitText(_ text: Text) -> () {
        // VALIDATION ENHANCEMENT: Potentially look for missing links or text that does not include a proposal ID
        for match in text.string.matches(of: /SE-\d\d\d\d/) {
            _previousProposalIDs.append(String(match.0))
        }
    }
}
