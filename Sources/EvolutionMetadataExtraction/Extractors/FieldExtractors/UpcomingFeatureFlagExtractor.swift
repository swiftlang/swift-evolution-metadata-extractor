// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct UpcomingFeatureFlagExtractor: MarkupWalker, ValueExtractor {

    private var source: HeaderFieldSource
    init(source: HeaderFieldSource) { self.source = source }

    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    private var flag: String?

    private var uff: Proposal.UpcomingFeatureFlag? {
        if let flag {
            return Proposal.UpcomingFeatureFlag(flag: flag)
        } else {
            return nil
        }
    }

    mutating func extractValue() -> ExtractionResult<Proposal.UpcomingFeatureFlag> {
        
        if let uffField = source["Upcoming Feature Flag"] {
            visit(uffField)
            
            // validate that flag is extracted if header is present
            if let flag {
                if flag.contains(/\s/) {
                    self.flag = nil
                    errors.append(.malformedUpcomingFeatureFlag)
                }
            } else {
                errors.append(.upcomingFeatureFlagExtractionFailure)
            }
            
        }
        
        return ExtractionResult(value: uff, warnings: warnings, errors: errors)
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        flag = inlineCode.code
    }
}
