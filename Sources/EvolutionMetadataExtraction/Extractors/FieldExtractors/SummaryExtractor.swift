
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct SummaryExtractor: ValueExtractor {
    
    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []
    
    func extractValue(from document: Document) -> ExtractionResult<String> {
                
        var summary = ""
        var foundIntroduction = false
        var foundIntroductionIndex = -1
        for child in document.children {
            
            if let heading = child as? Heading {
                if heading.plainText.contains("Introduction") {
                    foundIntroduction = true
                    foundIntroductionIndex = heading.indexInParent
                } else if foundIntroduction {
                    break
                }
            } else if foundIntroduction, let textConvertible = child as? any PlainTextConvertibleMarkup {
                //            let formatString = textConvertible.format(options: MarkupFormatter.Options(preferredLineLimit:MarkupFormatter.Options.PreferredLineLimit(maxLength: 80, breakWith: .softBreak)))
                let formatString = textConvertible.format()
                
                // The previous implementation did not find summaries if there was a some unrecognized element in the way, such as a blockquote or a paragraph with HTML markup
                // It probably makes sense to remove the (textConvertible.indexInParent - foundIntroductionIndex == 1) restriction after the transition
                if textConvertible.indexInParent - foundIntroductionIndex == 1 {
                    summary += formatString.replacingOccurrences(of: "\n\n", with: "").replacingOccurrences(of: " \n", with: "\n") + "\n"
                }
                break
            }
        }
        
        return ExtractionResult(value: summary, warnings: warnings, errors: errors)
    }
}
