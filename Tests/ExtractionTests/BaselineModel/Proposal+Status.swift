
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

extension Proposal_v1 {
    public enum Status: Equatable, Sendable, Comparable {
        case awaitingReview
        case scheduledForReview(start: String, end: String)
        case activeReview(start: String, end: String)
        case accepted
        case acceptedWithRevisions
        case previewing
        case implemented(version: String)
        case returnedForRevision
        case rejected
        case withdrawn
        case error
    }
}

extension Proposal_v1.Status: Codable {
    
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
            case "awaitingReview": self = .awaitingReview
            case "scheduledForReview":
                // VALIDATION ENHANCEMENT: On date parsing failure, legacy tool omits start and end keys
                // VALIDATION ENHANCEMENT: After move to new tool, revert to this being 'try' with failure
                // VALIDATION ENHANCEMENT: For this status, there should *always* be start and end values, even if empty strings
                let start = try? container.decode(String.self, forKey: .start)
                let end = try? container.decode(String.self, forKey: .end)
                self = .scheduledForReview(start: start ?? "", end: end ?? "")
            case "activeReview":
                // VALIDATION ENHANCEMENT: On date parsing failure, legacy tool omits start and end keys
                // VALIDATION ENHANCEMENT: After move to new tool, revert to this being 'try' with failure
                // VALIDATION ENHANCEMENT: For this status, there should *always* be start and end values, even if empty strings
                let start = try? container.decode(String.self, forKey: .start)
                let end = try? container.decode(String.self, forKey: .end)
                self = .activeReview(start: start ?? "", end: end ?? "")
            case "accepted": self = .accepted
            case "acceptedWithRevisions": self = .acceptedWithRevisions
            case "previewing": self = .previewing
            case "implemented":
                let version = try container.decode(String.self, forKey: .version)
                self = .implemented(version: version)
            case "returnedForRevision": self = .returnedForRevision
            case "rejected": self = .rejected
            case "withdrawn": self = .withdrawn
            case "error": self = .error
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
            case .awaitingReview: "awaitingReview"
            case .scheduledForReview: "scheduledForReview"
            case .activeReview: "activeReview"
            case .accepted: "accepted"
            case .acceptedWithRevisions: "acceptedWithRevisions"
            case .previewing: "previewing"
            case .implemented: "implemented"
            case .returnedForRevision: "returnedForRevision"
            case .rejected: "rejected"
            case .withdrawn: "withdrawn"
            case .error: "error"
        }
    }
}

extension Proposal_v1.Status {
    // VALIDATION ENHANCEMENT: Consider normalizing capitalization of statuses and validating correct capitalization
    public init?(name: String, version: String = "", start: String = "", end: String = "") {
        switch name.lowercased() {
            case "Awaiting Review".lowercased(): self = .awaitingReview
            case "Scheduled For Review".lowercased(): self = .scheduledForReview(start: start, end: end)
            case "Active Review".lowercased(): self = .activeReview(start: start, end: end)
            case "Accepted".lowercased(): self = .accepted
            case "Accepted With Revisions".lowercased(): self = .acceptedWithRevisions
            case "Previewing".lowercased(): self = .previewing
            case "Implemented".lowercased(): self = .implemented(version: version)
            case "Returned For Revision".lowercased(): self = .returnedForRevision
            case "Rejected".lowercased(): self = .rejected
            case "Withdrawn".lowercased(): self = .withdrawn
            case "Error".lowercased(): self = .error
            // VALIDATION ENHANCEMENT: The following are non-standard statuses that are in current proposals
            // VALIDATION ENHANCEMENT: The mapped values match the legacy tool implemenation
            // VALIDATION ENHANCEMENT: In the future may want to formalize or normalize
            case "Accepted with modifications".lowercased(): self = .accepted
            case "Partially implemented".lowercased(): self = .implemented(version: version)
            case "Implemented with Modifications".lowercased(): self = .implemented(version: version)
            default: return nil
        }
    }

    public var name: String {
        switch self {
            case .awaitingReview: "Awaiting Review"
            case .scheduledForReview: "Scheduled For Review"
            case .activeReview: "Active Review"
            case .accepted: "Accepted"
            case .acceptedWithRevisions: "Accepted With Revisions"
            case .previewing: "Previewing"
            case .implemented: "Implemented"
            case .returnedForRevision: "Returned For Revision"
            case .rejected: "Rejected"
            case .withdrawn: "Withdrawn"
            case .error: "Error"
        }
    }
}

