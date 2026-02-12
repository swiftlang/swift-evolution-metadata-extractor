// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct DiscussionExtractor: MarkupWalker, ValueExtractor {
    
    private var source: HeaderFieldSource
    init(source: HeaderFieldSource) { self.source = source }

    private var issues = IssueWrapper()
    private var discussions: [Proposal.Discussion] = []

    mutating func extractValue() -> ExtractionResult<[Proposal.Discussion]> {
        
        // VALIDATION ENHANCEMENT: Normalize naming to 'Review' in the source proposals.
        if let (_, headerField) = source["Review", "Reviews", "Decision Notes", "Decision notes"] {
            visit(headerField)
            
            // VALIDATION ENHANCEMENT: Correct proposals with known issues and remove special case logic.
            // Currently a fair number of older proposals are missing links to discussions or do not
            // format discussions correctly. Those issues should be corrected in the proposals themselves.
            // Once all of those issues are resolved, the legacy check can be removed.
            if discussions.isEmpty && !Legacy.discussionExtractionFailures.contains(source.proposalSpec.id) {
                issues.reportIssue(.discussionExtractionFailure, source: source)
            }
        } else {
            // VALIDATION ENHANCEMENT: Add field to proposals with missing field and remove special case logic.
            // 'Review' is a required field, but currently a fair number of older proposals are missing the
            // field for a variety of reasons. Those issues should be corrected in the proposals themselves.
            // Once all of those issues are resolved, the legacy check can be removed.
            // Note that some very early proposals may not have valid discussions be extracted.
            if !Legacy.missingReviewFields.contains(source.proposalSpec.id) {
                issues.reportIssue(.missingReviewField, source: source)
            }
        }
        
        // VALIDATION ENHANCEMENT: Potentially check for:
        // - Incorrect order of discussions (e.g. review before pitch)
        // - Non-standard naming
        //   - 1st instead of first
        //   - 'returned for revision' instead of 'revision'
        //   - Capitalized values
        //   - non-standard discussion names
        // - Formatting (in parenthesis, separated by comma, etc.
        
        return ExtractionResult(value: discussions, warnings: issues.warnings, errors: issues.errors)
    }
    
    // Existing proposals with known validation errors.
    // The listed exceptions will not generate warnings and errors for the known issues.
    private enum Legacy {
        static let missingReviewFields: Set<String> = ["SE-0001", "SE-0002", "SE-0004", "SE-0020", "SE-0051", "SE-0079", "SE-0100", "SE-0176", "SE-0177", "SE-0188", "SE-0193", "SE-0194", "SE-0196", "SE-0198", "SE-0201", "SE-0203", "SE-0205", "SE-0208", "SE-0209", "SE-0210", "SE-0212", "SE-0213", "SE-0219", "SE-0243", "SE-0245", "SE-0247", "SE-0248", "SE-0249", "SE-0250", "SE-0252", "SE-0259", "SE-0263", "SE-0268", "SE-0269", "SE-0273", "SE-0278", "SE-0284", "SE-0289", "SE-0295", "SE-0300", "SE-0303", "SE-0304", "SE-0312", "SE-0313", "SE-0317", "SE-0318", "SE-0337", "SE-0338", "SE-0341", "SE-0343", "SE-0344", "SE-0348", "SE-0350", "SE-0356", "SE-0365", "SE-0385"]
        
        static let discussionExtractionFailures: Set<String> = ["SE-0392"]
    }
    
    mutating func visitLink(_ link: Link) -> () {
        guard let linkInfo = LinkInfo(link: link) else {
            return
        }
        
        // VALIDATION ENHANCEMENT: Potentially check for links with numbers as last two path components.
        // This would catch cases not linked to the top of the discussion, but a post in the middle.
        if let discussionURL = linkInfo.swiftForumsDestination {
            discussions.append(Proposal.Discussion(name: linkInfo.text, link: discussionURL))
        } else {
            issues.reportIssue(.invalidDiscussionLink, source: source)
        }
    }
}
