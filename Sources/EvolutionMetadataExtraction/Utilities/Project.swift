// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

// typealias improves readability of validationExemptions definitions
fileprivate typealias Issue = Proposal.Issue

/**
 Represents a software project with its own set of evolution proposals.
 */
public final class Project: Sendable {
    let name: String
    let organization: String
    let repository: String
    let path: String
    let proposalPrefix: String
    nonisolated(unsafe) let proposalRegex: Regex<Substring>
    let previousResultsURL: URL
    let defaultOutputFilename: String
    private let endpointBaseURL: URL
    let mainBranchEndpoint: URL
    let proposalListingEndpoint: URL
    let validationExemptions: [Int:RangeSet<Int>]
    
    private init(name: String, organization: String, repository: String, path: String, proposalPrefix: String, proposalRegex: Regex<Substring>, previousResultsURL: URL, defaultOutputFilename: String, validationExemptions: [Int:RangeSet<Int>]) {
        self.name = name
        self.organization = organization
        self.repository = repository
        self.path = path
        self.proposalPrefix = proposalPrefix
        self.proposalRegex = proposalRegex
        self.previousResultsURL = previousResultsURL
        self.defaultOutputFilename = defaultOutputFilename
        self.validationExemptions = validationExemptions

        self.endpointBaseURL = URL(string: "https://api.github.com/repos/")!.appending(components: organization, repository)
        self.mainBranchEndpoint = endpointBaseURL.appending(path:"branches/main")
        self.proposalListingEndpoint = endpointBaseURL.appending(path: "contents/" + path)
    }

    func githubPullEndpoint(for request: Int) -> URL {
        endpointBaseURL.appending(path: "pulls/\(request)/files")
            .appending(queryItems: [URLQueryItem(name: "per_page", value: "100")])
    }

    public static var `default`: Project {
        swift
    }

    public static let swift = Project(
        name: "Swift",
        organization: "swiftlang",
        repository: "swift-evolution",
        path: "proposals",
        proposalPrefix: "SE",
        proposalRegex: /^SE-\d\d\d\d$/,
        previousResultsURL: URL(string: "https://download.swift.org/swift-evolution/v1/evolution.json")!,
        defaultOutputFilename: "evolution.json",
        validationExemptions: [
    
            // 'Review' is a required field, but currently a fair number of older proposals are missing the
            // field for a variety of reasons. Those issues should be corrected in the proposals themselves.
            // Once corrected, the exemption for the corrected proposal can be removed.
            // Note that some early proposals may not have valid discussions be added and will always need exemption.
            Issue.missingReviewField.code:
                RangeSet([0001, 0002, 0004, 0020, 0051, 0079, 0100, 0176, 0177, 0188, 0193, 0194, 0196, 0198, 0201, 0203, 0205, 0208, 0209, 0210, 0212, 0213, 0219, 0243, 0245, 0247, 0248, 0249, 0250, 0252, 0259, 0263, 0268, 0269, 0273, 0278, 0284, 0289, 0295, 0300, 0303, 0304, 0312, 0313, 0317, 0318, 0337, 0338, 0341, 0343, 0344, 0348, 0350, 0356, 0365, 0385]),

            // Some older proposals are missing links to discussions or do not format discussions correctly.
            // Those issues should be corrected in the proposals themselves.
            // Once corrected, the exemption for the corrected proposal can be removed.
            Issue.discussionExtractionFailure.code:
                RangeSet(0392),
        ]
    )

    public static let swiftTesting = Project(
        name: "Swift Testing",
        organization: "swiftlang",
        repository: "swift-evolution",
        path: "proposals/testing",
        proposalPrefix: "ST",
        proposalRegex: /^ST-\d\d\d\d$/,
        previousResultsURL: URL(string: "https://download.swift.org/swift-evolution/v1/testing-evolution.json")!,
        defaultOutputFilename: "testing-evolution.json",
        validationExemptions: [:]
    )

    public static let foundation = Project(
        name: "Foundation",
        organization: "swiftlang",
        repository: "swift-foundation",
        path: "Proposals",
        proposalPrefix: "SF",
        proposalRegex: /^SF-\d\d\d\d$/,
        previousResultsURL: URL(string: "https://download.swift.org/swift-evolution/v1/foundation-evolution.json")!,
        defaultOutputFilename: "foundation-evolution.json",
        validationExemptions: [:]
    )
}

// MARK: - Range and RangeSet Extensions

/* Extensions to Range and RangeSet to increase clarity of validationExemptions definitions */

private extension Range where Bound == Int {
    static func upTo(_ upperBound: Int) -> Range { 0..<upperBound }
}

private extension RangeSet where Bound == Int {
    static var allExempt: RangeSet { RangeSet(0..<Int.max) }
}

/*  Creates a Range from an integer literal of the form value..<(value + 1).
    For Int.max, the lower and upper bounds of the range are Int.max.
    Although a retroactive conformance, the risk of this being officially added
    to the standard library is very low.
 */
extension Range: @retroactive ExpressibleByIntegerLiteral where Bound == Int {
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: Int) {
        self.init(uncheckedBounds: (lower: value, upper: value == Int.max ? Int.max : value + 1))
    }
}
