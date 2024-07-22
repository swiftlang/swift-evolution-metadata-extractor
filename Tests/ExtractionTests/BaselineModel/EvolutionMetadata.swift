
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

/* The baseline model is used by the testForBreakingChanges() test to ensure that a change to the generated JSON does not break existing clients.
 
 Baseline model types use the schema in the name of its types, for example `EvolutionMetadata_v1` and `Proposal_v1`.
 
 When the schema changes and the minor or major versions increment, the basline model should be updated and the naming of its types updated to match the schema version.
 
 Note the version number is not the full semantic versioning version, trailing zeros are omitted. (e.g. v1 vs v1_0_0 or v1_1 vs v1_1_0)

 */

public struct EvolutionMetadata_v1: Equatable, Sendable, Codable {
    
    /// Schema version of this struct and its related types
    public static let schemaVersion = "1.0.0"

    /// Creation date as a ISO 8601 formatted string
    public var creationDate: String
    
    /// Sorted array of Swift versions of proposals with 'implemented' status
    public var implementationVersions: [String]
    
    /// Array of proposal metadata instances
    public var proposals: [Proposal_v1]
    
    /// The swift-evolution repository commit used as the metadata source
    public var commit: String

    /// Schema version of the decoded metadata
    public var schemaVersion: String

    /// Version of the tool that performed the metadata extraction
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
