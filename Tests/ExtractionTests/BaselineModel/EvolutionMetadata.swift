
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

public struct EvolutionMetadata_v1: Equatable, Sendable, Codable {
    public static let schemaVersion = "0.1.0"
    public var creationDate: String
    public var implementationVersions: [String]
    public var proposals: [Proposal_v1]
    public var commit: String
    public var schemaVersion: String
    public var toolVersion: String
    public init(creationDate: String, implementationVersions: [String], proposals: [Proposal_v1], commit: String, toolVersion: String) {
        self.creationDate = creationDate
        self.implementationVersions = implementationVersions
        self.proposals = proposals
        self.schemaVersion = EvolutionMetadata_v1.schemaVersion
        self.commit = commit
        self.toolVersion = toolVersion
    }
}