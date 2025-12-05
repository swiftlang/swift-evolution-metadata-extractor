// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal_v1 {
    
    /// Enum representing the status of the proposal
    ///
    /// The `scheduledForReview` and `activeReview` cases have associated `start` and `end` values indicating the review period.
    /// These values are ISO 8601 formatted strings.
    ///
    /// The `implemented` case has an associated`version` value with the Swift version that implements the proposal.
    ///
    /// The `error` case has an associated `reason` version with a diagnostic string.
    /// 
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
        
        /// Error
        ///
        /// The error status is not part of the Swift Evolution process. It represents an error in extracting or decoding the metadata.
        ///
        /// The error status is used:
        ///  - During encoding when a status value cannot be extracted from the proposal.
        ///    In these cases there should be an error in the `errors` array detailing the issue.
        ///
        ///  - During decoding if an unexpected status value is found. The associated `reason` string will include the unexpected status value.
        ///
        case error(reason: String)
        
        // Error status reason values
        public static let statusExtractionNotAttempted: Status = .error(reason: "Status extraction not attempted")
        public static let statusExtractionFailed: Status = .error(reason: "Status extraction failed")
        public static func unknownStatus(_ status: String) -> Status {
            .error(reason: "Unknown status value '\(status)'")
        }
    }
}

extension Proposal_v1.Status: Codable {
    
    enum CodingKeys: String, CodingKey {
        case state
        case version
        case start
        case end
        case reason
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(String.self, forKey: .state)

        switch state {
            case "awaitingReview": self = .awaitingReview
            case "scheduledForReview":
                let start = try container.decode(String.self, forKey: .start)
                let end = try container.decode(String.self, forKey: .end)
                self = .scheduledForReview(start: start, end: end)
            case "activeReview":
                let start = try container.decode(String.self, forKey: .start)
                let end = try container.decode(String.self, forKey: .end)
                self = .activeReview(start: start, end: end)
            case "accepted": self = .accepted
            case "acceptedWithRevisions": self = .acceptedWithRevisions
            case "previewing": self = .previewing
            case "implemented":
                let version = try container.decode(String.self, forKey: .version)
                self = .implemented(version: version)
            case "returnedForRevision": self = .returnedForRevision
            case "rejected": self = .rejected
            case "withdrawn": self = .withdrawn
            case "error":
                let reason = try container.decode(String.self, forKey: .reason)
                self = .error(reason: reason)
            default:
                self = .unknownStatus(state)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        let state = switch self {
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
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
        
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
        
        if case let .error(reason) = self {
            try container.encode(reason, forKey: .reason)
        }
    }
}
