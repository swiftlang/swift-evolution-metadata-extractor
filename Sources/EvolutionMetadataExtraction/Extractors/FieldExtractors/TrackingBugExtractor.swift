// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

struct TrackingBugExtractor: MarkupWalker, ValueExtractor {

    private var source: HeaderFieldSource
    init(source: HeaderFieldSource) { self.source = source }

    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    private var trackingBugs: [Proposal.TrackingBug]? {
        _trackingBugs.isEmpty ? nil : _trackingBugs
    }
    private var _trackingBugs: [Proposal.TrackingBug] = []

    mutating func extractValue() -> ExtractionResult<[Proposal.TrackingBug]> {
        if let (_, headerField) = source["Bug", "Bugs"] {
            visit(headerField)
        }
        
        // Bug field is optional. Take no action / add no warning if it is not found
        
        return ExtractionResult(value: trackingBugs, warnings: warnings, errors: errors)
    }
    
    mutating func visitLink(_ link: Link) -> () {
        guard let values = LinkInfo(link: link) else {
            // VALIDATION ENHANCEMENT: Add warning or error malformed / misformatted status
            return
        }
        let trackingBug = Proposal.TrackingBug(id: values.text, link: values.destination)
        _trackingBugs.append(trackingBug)
    }
}
