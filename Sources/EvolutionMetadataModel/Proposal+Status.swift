
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

extension Proposal {
    public enum Status: Equatable, Sendable, Comparable {
        case awaitingReview
        case scheduledForReview(String, String)
        case activeReview(String, String)
        case returnedForRevision
        case withdrawn
        case deferred
        case accepted
        case acceptedWithRevisions
        case rejected
        case implemented(String)
        case previewing
        case error
    }
}

extension Proposal.Status: Codable {
    
    enum CodingKeys: String, CodingKey {
        case state
        case version
        case start
        case end
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .state)

        switch status {
            case ".awaitingReview": self = .awaitingReview
            case ".scheduledForReview":
                // VALIDATION ENHANCEMENT: On date parsing failure, legacy tool omits start and end keys
                // VALIDATION ENHANCEMENT: After move to new tool, revert to this being 'try' with failure
                // VALIDATION ENHANCEMENT: For this status, there should *always* be start and end values, even if empty strings
                let start = try? container.decode(String.self, forKey: .start)
                let end = try? container.decode(String.self, forKey: .end)
                self = .scheduledForReview(start ?? "", end ?? "")
            case ".activeReview":
                // VALIDATION ENHANCEMENT: On date parsing failure, legacy tool omits start and end keys
                // VALIDATION ENHANCEMENT: After move to new tool, revert to this being 'try' with failure
                // VALIDATION ENHANCEMENT: For this status, there should *always* be start and end values, even if empty strings
                let start = try? container.decode(String.self, forKey: .start)
                let end = try? container.decode(String.self, forKey: .end)
                self = .activeReview(start ?? "", end ?? "")
            case ".returnedForRevision": self = .returnedForRevision
            case ".withdrawn": self = .withdrawn
            case ".deferred": self = .deferred
            case ".accepted": self = .accepted
            case ".acceptedWithRevisions": self = .acceptedWithRevisions
            case ".rejected": self = .rejected
            case ".implemented":
                let version = try container.decode(String.self, forKey: .version)
                self = .implemented(version)
            case ".previewing": self = .previewing
            case ".error": self = .error
            default: throw DecodingError.dataCorruptedError(forKey: .state, in: container,
                                                            debugDescription: "Unknown status value \(status)"
            )
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.codingValue, forKey: .state)
        
        if case let .scheduledForReview(startDate, endDate) = self {
            try container.encode(startDate, forKey: .start)
            try container.encode(endDate, forKey: .end)
        }
        
        if case let .activeReview(startDate, endDate) = self {
            try container.encode(startDate, forKey: .start)
            try container.encode(endDate, forKey: .end)
        }
        
        if case let .implemented(version) = self {
            try container.encode(version, forKey: .version)
        }
    }
    
    var codingValue: String {
        switch self {
            case .awaitingReview: ".awaitingReview"
            case .scheduledForReview: ".scheduledForReview"
            case .activeReview: ".activeReview"
            case .returnedForRevision: ".returnedForRevision"
            case .withdrawn: ".withdrawn"
            case .deferred: ".deferred"
            case .accepted: ".accepted"
            case .acceptedWithRevisions: ".acceptedWithRevisions"
            case .rejected: ".rejected"
            case .implemented: ".implemented"
            case .previewing: ".previewing"
            case .error: ".error"
        }
    }
}

extension Proposal.Status {
    // VALIDATION ENHANCEMENT: Consider normalizing capitalization of statuses and validating correct capitalization
    public init?(name: String, version: String = "", start: String = "", end: String = "") {
        switch name.lowercased() {
            case "Awaiting Review".lowercased(): self = .awaitingReview
            case "Scheduled For Review".lowercased(): self = .scheduledForReview(start, end)
            case "Active Review".lowercased(): self = .activeReview(start, end)
            case "Returned For Revision".lowercased(): self = .returnedForRevision
            case "Withdrawn".lowercased(): self = .withdrawn
            case "Deferred".lowercased(): self = .deferred
            case "Accepted".lowercased(): self = .accepted
            case "Accepted With Revisions".lowercased(): self = .acceptedWithRevisions
            case "Rejected".lowercased(): self = .rejected
            case "Implemented".lowercased(): self = .implemented(version)
            case "Previewing".lowercased(): self = .previewing
            case "Error".lowercased(): self = .error
            // VALIDATION ENHANCEMENT: The following are non-standard statuses that are in current proposals
            // VALIDATION ENHANCEMENT: The mapped values match the legacy tool implemenation
            // VALIDATION ENHANCEMENT: In the future may want to formalize or normalize
            case "Accepted with modifications".lowercased(): self = .accepted
            case "Partially implemented".lowercased(): self = .implemented(version)
            case "Implemented with Modifications".lowercased(): self = .implemented(version)
            default: return nil
        }
    }

    public var name: String {
        switch self {
            case .awaitingReview: "Awaiting Review"
            case .scheduledForReview: "Scheduled For Review"
            case .activeReview: "Active Review"
            case .returnedForRevision: "Returned For Revision"
            case .withdrawn: "Withdrawn"
            case .deferred: "Deferred"
            case .accepted: "Accepted"
            case .acceptedWithRevisions: "Accepted With Revisions"
            case .rejected: "Rejected"
            case .implemented: "Implemented"
            case .previewing: "Previewing"
            case .error: "Error"
        }
    }
}

