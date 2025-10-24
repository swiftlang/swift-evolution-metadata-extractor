
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

public struct EvolutionMetadata: Sendable, Hashable, Codable {
    
    /// Schema version of this struct and its related types
    public static let schemaVersion = "1.0.0"

    /// Creation date as a ISO 8601 formatted string
    public var creationDate: String
    
    /// Sorted array of Swift versions of proposals with 'implemented' status
    public var implementationVersions: [String]
    
    /// Array of proposal metadata instances
    public var proposals: [Proposal]
    
    /// The swift-evolution repository commit used as the metadata source
    public var commit: String

    /// Schema version of the decoded metadata
    public var schemaVersion: String

    /// Version of the tool that performed the metadata extraction
    public var toolVersion: String

    public init(creationDate: String, implementationVersions: [String], proposals: [Proposal], commit: String, toolVersion: String) {
        self.creationDate = creationDate
        self.implementationVersions = implementationVersions
        self.proposals = proposals
        self.schemaVersion = EvolutionMetadata.schemaVersion
        self.commit = commit
        self.toolVersion = toolVersion
    }
}
