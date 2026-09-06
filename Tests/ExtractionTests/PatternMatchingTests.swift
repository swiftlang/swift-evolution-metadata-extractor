// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Testing
import Foundation

@testable import EvolutionMetadataModel
@testable import EvolutionMetadataExtraction

@Suite
struct `Pattern Matching` {

    // The lines of text in review-dates-good.txt are status headers from swift-evolution repository history
    @Test func `Good dates`() throws {

        let reviewDatesContents = try string(forResource: "review-dates-good", withExtension: "txt")

        let statusStrings = reviewDatesContents.split(separator: "\n")
        for statusString in statusStrings {
            // NOTE: This is something that should be validated!
            // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
            let match = try #require(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )

            let statusDetail = String(match.1)

            #expect(StatusExtractor.datesForString(statusDetail) != nil, "Unable to parse '\(statusDetail)'")
        }
    }

    @Test(arguments: try {
        // The lines of text in review-dates-bad.txt are status headers from swift-evolution repository history
        let reviewDatesContents = try string(forResource: "review-dates-bad", withExtension: "txt")
        return reviewDatesContents.split(separator: "\n").map(String.init)
    }())
    func `Bad dates`(statusString: String) throws {

        // NOTE: This is something that should be validated!
        // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
        let match = try #require(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )

        let statusDetail = String(match.1)

        #expect(StatusExtractor.datesForString(statusDetail) == nil, "Unexpectedly able to parse '\(statusDetail)'")
    }
}
