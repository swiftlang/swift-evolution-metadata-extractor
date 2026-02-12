// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Markdown
import EvolutionMetadataModel

// VALIDATION ENHANCEMENT: Add test that checks against valid header field labels
struct HeaderFieldExtractor: MarkupWalker, ValueExtractor {

    private var source: DocumentSource
    init(source: DocumentSource) { self.source = source }

    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    private var headerItemsByLabel: [String: ListItem] = [:]

    mutating func extractValue() -> ExtractionResult<[String: ListItem]> {
        guard let headerFields = source.document.child(through: [(1, UnorderedList.self)]) as? UnorderedList else {
            return ExtractionResult(value: nil, warnings: warnings, errors: errors)
        }
        visit(headerFields)
        return ExtractionResult(value: headerItemsByLabel, warnings: warnings, errors: errors)
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        // The first paragraph / text in each list item is the label
        if let headerLabelElement = listItem.child(through: [(0, Paragraph.self), (0, Text.self)]) as? Text {
            let headerLabel = String(headerLabelElement.string.prefix { $0 != ":" })
            // VALIDATION ENHANCEMENT: Check for duplicate headers
//            if let _ = headerItemsByLabel[headerLabel] {
//                verbosePrint("Header \(headerLabel) appears more than once")
//            }
            headerItemsByLabel[headerLabel] = listItem
            // In a handful of cases, a header field is simply a link with no label
        } else if let headerLabelLink = listItem.child(through: [(0, Paragraph.self), (0, Link.self)]) as? Link, let value = LinkInfo(link: headerLabelLink) {
            headerItemsByLabel[value.text] = listItem
        } else {
            // VALIDATION ENHANCEMENT: Record error or warning of malformed header item
            print()
            print("Unable to extract from header item:")
            print(listItem.debugDescription())
            return
        }
    }
}
