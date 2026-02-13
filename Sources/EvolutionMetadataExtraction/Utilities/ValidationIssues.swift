// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

// VALIDATION ENHANCEMENTS: After validation enhancements, consider moving the full list of known issues to EvolutionMetadataModel as an extension to Proposal.Issue. Possibly then add ValidationIssue as a typealias.

extension Proposal.Issue {

    // MARK: - Document-Level Errors
    // VALIDATION ENHANCEMENTS: Consider making a stronger 'unable to fetch or read proposal' statement
    static let proposalContainsNoContent = Proposal.Issue(
        kind: .error,
        code: 1,
        message: "Proposal contains no content."
    )

    static let emptyMarkdownFile = Proposal.Issue(
        kind: .error,
        code: 2,
        message: "Proposal Markdown file is empty."
    )

    static let missingMetadataFields = Proposal.Issue(
        kind: .error,
        code: 3,
        message: "Missing list of metadata fields."
    )

    // MARK: - Heading Errors

    // MARK: - Title
    // TODO: title missing = 10
    // TODO: title wrong heading level = 11
    
    // MARK: - Summary of changes
    // TODO: summary missing = 20
    // TODO: summary wrong heading level = 21
    // TODO: summary too long = 22
    // TODO: summary multiple paragraphs = 23

    // MARK: - Header Field Errors

    // MARK: - Proposal
    static let missingProposalField = Proposal.Issue(
        kind: .error,
        code: 30,
        message: "Missing proposal field."
    )

    static let missingProposalIDLink = Proposal.Issue(
        kind: .error,
        code: 31,
        message: "Missing proposal ID link (SE-NNNN)[NNNN-filename.md]."
    )

    static let proposalIDWrongDigitCount = Proposal.Issue(
        kind: .error,
        code: 32,
        message: "Proposal ID must include four decimal digits."
    )

    static let proposalIDHasExtraMarkup = Proposal.Issue(
        kind: .warning,
        code: 33,
        message: "Proposal ID contains extra markup; expected a link with plaintext contents."
    )

    static let invalidProposalIDLink = Proposal.Issue(
        kind: .error,
        code: 34,
        message: "Proposal ID link must be a relative link (SE-NNNN)[NNNN-filename.md]."
    )

    static let reservedProposalID = Proposal.Issue(
        kind: .error,
        code: 34,
        message: "Missing valid proposal ID; SE-0000 is reserved."
    )

    // MARK: - Author
    static let missingAuthors = Proposal.Issue(
        kind: .error,
        code: 40,
        message: "Missing author(s)."
    )

    static let authorsHaveExtraMarkup = Proposal.Issue(
        kind: .error,
        code: 41,
        message: "Author name contains extra markup; expected a link with plaintext contents."
    )

    static let authorMissingProfileLink = Proposal.Issue(
        kind: .error,
        code: 42,
        message: "Author missing link."
    )

    static let invalidAuthorLink = Proposal.Issue(
        kind: .warning,
        code: 43,
        message: "Author's link doesn't refer to a GitHub profile. Link removed."
    )

    // MARK: - Review Manager
    static let missingReviewManagers = Proposal.Issue(
        kind: .error,
        code: 50,
        message: "Missing review manager(s)."
    )

    // Currently unused.
    // Consider changing to reviewManagersHaveExtraMarkup to mirror author error
    static let multipleReviewManagers = Proposal.Issue(
        kind: .warning,
        code: 51,
        message: "Multiple review managers listed without profile links."
    )

    static let reviewManagerMissingProfileLink = Proposal.Issue(
        kind: .error,
        code: 52,
        message: "Review manager missing profile link."
    )

    static let invalidReviewManagerLink = Proposal.Issue(
        kind: .warning,
        code: 53,
        message: "Review manager's link doesn't refer to a GitHub profile. Link removed."
    )

    // MARK: - Status
    // VALIDATION ENHANCEMENT: Why is this only a warning?
    static let missingStatus = Proposal.Issue(
        kind: .warning,
        code: 60,
        message: "Status not found in the proposal's details list."
    )

    // How different from missingStatus?
    static let missingOrInvalidStatus = Proposal.Issue(
        kind: .error,
        code: 61,
        message: "Missing or invalid proposal status."
    )

    static let missingImplementedVersion = Proposal.Issue(
        kind: .warning,
        code: 62,
        message: "Missing Swift version number for an implemented proposal."
    )

    static let missingOrInvalidReviewDates = Proposal.Issue(
        kind: .warning,
        code: 63,
        message: "Missing or invalid dates for a review period."
    )

    // MARK: - Bugs
    // TODO: malformed bug = 70

    // MARK: - Implementation
    static let invalidImplementationLink = Proposal.Issue(
        kind: .warning,
        code: 80,
        message: "Implementation links to a non-Swift repository."
    )

    // MARK: - Upcoming Feature Flag
    static let upcomingFeatureFlagExtractionFailure = Proposal.Issue(
        kind: .error,
        code: 90,
        message: "Failed to extract upcoming feature flag."
    )

    static let malformedUpcomingFeatureFlag = Proposal.Issue(
        kind: .error,
        code: 91,
        message: "Upcoming feature flag should not contain whitespace."
    )

    // MARK: - Previous Proposal
    static let previousProposalIDsExtractionFailure = Proposal.Issue(
        kind: .error,
        code: 100,
        message: "Failed to extract previous proposal IDs."
    )

    // MARK: - Review
    static let missingReviewField = Proposal.Issue(
        kind: .error,
        code: 110,
        message: "Missing Review field."
    )

    static let discussionExtractionFailure = Proposal.Issue(
        kind: .error,
        code: 111,
        message: "Failed to extract discussions from Review field."
    )

    static let invalidDiscussionLink = Proposal.Issue(
        kind: .warning,
        code: 112,
        message: "Discussion link doesn't refer to a Swift forum thread. Discussion removed."
    )
}
