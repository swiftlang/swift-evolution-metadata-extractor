// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

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
        validationExemptions: [:]
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
