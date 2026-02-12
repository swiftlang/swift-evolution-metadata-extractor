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
            if discussions.isEmpty {
                issues.reportIssue(.discussionExtractionFailure, source: source)
            }
        } else {
            issues.reportIssue(.missingReviewField, source: source)
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
