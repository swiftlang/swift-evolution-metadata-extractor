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

    struct VersionTestArgs {
        let source: String; let expectedResult: String?; let expectedDiagnostics: DiagnosticMessageSet
        init(_ source: String, _ expectedResult: String?, _ expectedDiagnostics: DiagnosticMessageSet) {
            self.source = source; self.expectedResult = expectedResult; self.expectedDiagnostics = expectedDiagnostics
        }
    }
    let moreArgs = {["2.2", "3.0", "3.0.1", "3.1", "4.0", "4.1", "4.2", "5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.5.2", "5.6", "5.7", "5.8", "5.9", "5.9.2", "5.10", "6.0", "6.1", "6.2", "6.2.3", "6.3", "6.4", "Next"].map { VersionTestArgs($0, $0, [])
    }}()
    
    @Test(arguments: [
        // correct values
        VersionTestArgs("Swift 5.6", "5.6", []),
        VersionTestArgs("Swift 5.9.2", "5.9.2", []),
        VersionTestArgs("Swift 5.10", "5.10", []),
        VersionTestArgs("Swift 5.999.10", "5.999.10", []),
        VersionTestArgs("Swift 5.12345.888", "5.12345.888", []),
        VersionTestArgs("Swift Next", "Next", []),

        // diagnosable malformed values
        VersionTestArgs("4.3", "4.3", [.swiftMissing]),
        VersionTestArgs("Swift 5", nil, [.minorVersionMissing]),
        VersionTestArgs("swift 6", nil, [.minorVersionMissing, .swiftMiscapitalized]),
        VersionTestArgs("4", nil, [.minorVersionMissing, .swiftMissing]),
        VersionTestArgs("Next", "Next", [.swiftMissing]),
        VersionTestArgs("next", "Next", [.swiftMissing, .nextMiscapitalized]),
        VersionTestArgs("swift Next", "Next", [.swiftMiscapitalized]),
        VersionTestArgs("Swift 4.2 except for standard library", "4.2", [.extraText]),
        VersionTestArgs("Committed to Swift 5.1", "5.1", [.extraText]),
        VersionTestArgs("swift 5.6", "5.6", [.swiftMiscapitalized]),
        VersionTestArgs("Swift 15.6", nil, [.majorVersionTooLarge]),
        VersionTestArgs("Swift 10", nil, [.majorVersionTooLarge, .minorVersionMissing]),
        VersionTestArgs("Swift next", "Next", [.nextMiscapitalized]),
        VersionTestArgs("swift next", "Next", [.nextMiscapitalized, .swiftMiscapitalized]),
        VersionTestArgs("swift 10.3", nil, [.majorVersionTooLarge, .swiftMiscapitalized]),
        VersionTestArgs("swift 11", nil, [.majorVersionTooLarge, .minorVersionMissing, .swiftMiscapitalized]),

        // completely wrong
        VersionTestArgs("Lately", nil, []),
        VersionTestArgs("Blah Blah", nil, []),

//        VersionTestArgs("SWUFT 6.4", nil, []),

    ])
    func `Implementation versions`(argument: VersionTestArgs) throws {
        let (version, diagnostics) = StatusExtractor.versionResultForString(argument.source)

        if !diagnostics.isEmpty || version == nil {
            let issue = Proposal.Issue.malformedImplementationVersion(source: argument.source, diagnostics: diagnostics)
            print(issue.validationReport(indentLevel: 1))
            print("------")
        }
        #expect(version == argument.expectedResult)
        #expect(diagnostics == argument.expectedDiagnostics)
    }
}
