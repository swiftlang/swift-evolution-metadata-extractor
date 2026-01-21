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
        for child in document.children {

            // VALIDATION ENHANCEMENT: Potential for stricter validation of section heading and contents
            // https://github.com/swiftlang/swift-evolution-metadata-extractor/issues/77
            // https://github.com/swiftlang/swift-evolution-metadata-extractor/issues/78
            if let heading = child as? Heading {
                if heading.plainText.contains("Introduction") || heading.plainText.contains("Summary of change") || heading.plainText.contains("Summary Of Change") {
                    foundIntroduction = true
                } else if foundIntroduction {
                    break
                }
            } else if foundIntroduction, let textConvertible = child as? any PlainTextConvertibleMarkup {

                let formatString = textConvertible.format()
                 
                // The returned string begins with two consecutive newlines
                // A hard line break in the middle of a paragraph appears as a single newline
                // A hard line break followed by a backtick appears as two consecutive newlines

                // To adjust find matches of one or two newlines.
                // If the match is at the start of the string, replace with empty string.
                // Otherwise replace it with a space.
                let processedSummary = formatString.replacing(/\n\n?/) { match in
                    match.range.lowerBound == formatString.startIndex ? "" : " "
                }
                summary += processedSummary

                break // Break to include only the first plain text convertable (typically a paragraph)
            }
        }
        
        return ExtractionResult(value: summary, warnings: warnings, errors: errors)
    }
}
