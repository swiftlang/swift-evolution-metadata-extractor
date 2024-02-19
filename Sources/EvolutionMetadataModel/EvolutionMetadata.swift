
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

public struct EvolutionMetadata: Equatable, Sendable, Codable {
    public static let schemaVersion = "0.1.0"
    public var creationDate: String
    public var implementationVersions: [String]
    public var proposals: [Proposal]
    public var sha: String
    public var schemaVersion: String
    public var toolVersion: String
    public init(creationDate: String, implementationVersions: [String], proposals: [Proposal], sha: String, toolVersion: String) {
        self.creationDate = creationDate
        self.implementationVersions = implementationVersions
        self.proposals = proposals
        self.schemaVersion = EvolutionMetadata.schemaVersion
        self.sha = sha
        self.toolVersion = toolVersion
    }
}
