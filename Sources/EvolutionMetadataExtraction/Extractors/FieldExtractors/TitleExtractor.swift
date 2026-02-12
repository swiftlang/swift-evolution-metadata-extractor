// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct TitleExtractor: ValueExtractor {

    private var source: DocumentSource
    init(source: DocumentSource) { self.source = source }

    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    mutating func extractValue() -> ExtractionResult<String> {
        
        var title: String?
        
        if let titleElement = source.document.child(at: 0) as? Heading {
            
            // VALIDATION ENHANCEMENT: Add warning or error that the title is badly formatted in the markdown
//            if titleElement.level != 1 {
//            }
            
            title = titleElement.plainText
            
        } else {
            errors.append(.proposalContainsNoContent)
        }
        return ExtractionResult(value: title, warnings: warnings, errors: errors)
        
    }
}

