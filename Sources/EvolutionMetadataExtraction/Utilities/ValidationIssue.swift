
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

enum ValidationIssue {
    
    // MARK: - Parse Errors
    // VALIDATION ENHANCEMENTS: Consider making a stronger 'unable to fetch or read proposal' statement
    static let proposalContainsNoContent = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Proposal contains no content."
    )
    
    static let emptyMarkdownFile = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Proposal Markdown file is empty."
    )
    
    static let missingMetadataFields = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Missing list of metadata fields."
    )
    
    static let missingOrInvalidStatus = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Missing or invalid proposal status."
    )
 // How different from missingStatus?
    static let missingProposalIDLink = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Missing proposal ID link (SE-NNNN)[NNNN-filename.md]."
    )

    static let proposalIDWrongDigitCount = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Proposal ID must include four decimal digits."
    )

    static let missingAuthors = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Missing author(s)."
    )

    static let authorsHaveExtraMarkup = Proposal.Issue(
        kind: .error,
        stage: .parse,
        message: "Author name contains extra markup; expected a link with plaintext contents."
    )
    
    // MARK: - Parse Warnings
    
    // VALIDATION ENHANCEMENT: Why is this only a warning?
    static let missingStatus = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Status not found in the proposal's details list."
    )

    static let missingImplementedVersion = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Missing Swift version number for an implemented proposal."
    )

    static let missingOrInvalidReviewDates = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Missing or invalid dates for a review period."
    )

    static let proposalIDHasExtraMarkup = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Proposal ID contains extra markup; expected a link with plaintext contents."
    )

    static let missingReviewManagers = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Missing review manager(s)."
    )

    static let multipleReviewManagers = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Multiple review managers listed without profile links."
    )

    static let reviewManagerMissingProfileLink = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Review manager missing profile link."
    )

    static let authorMissingProfileLink = Proposal.Issue(
        kind: .warning,
        stage: .parse,
        message: "Author missing link."
    )
    
    // MARK: - Validation Errors
    
    static let invalidProposalIDLink = Proposal.Issue(
        kind: .error,
        stage: .validate,
        message: "Proposal ID link must be a relative link (SE-NNNN)[NNNN-filename.md]."
    )

    static let reservedProposalID = Proposal.Issue(
        kind: .error,
        stage: .validate,
        message: "Missing valid proposal ID; SE-0000 is reserved."
    )
    
    // MARK: - Validation Warnings
    
    static let invalidAuthorLink = Proposal.Issue(
        kind: .warning,
        stage: .validate,
        message: "Author's link doesn't refer to a GitHub profile. Link removed."
    )

    static let invalidReviewManagerLink = Proposal.Issue(
        kind: .warning,
        stage: .validate,
        message: "Review manager's link doesn't refer to a GitHub profile. Link removed."
    )

    static let invalidImplementationLink = Proposal.Issue(
        kind: .warning,
        stage: .validate,
        message: "Implementation links to a non-Swift repository."
    )

    // VALIDATION ENHANCEMENTS: Consider not including the date in the review message, or not including time components.
    // Comparing results currently breaks if recorded test values and actual values are generated in different time zones.
    // Using GMT with generated legacy tool results to avoid for the present
    static func reviewEnded(on endDate: Date) -> Proposal.Issue {
        var calender = Calendar(identifier: .gregorian)
        calender.timeZone = TimeZone.gmt
        return Proposal.Issue(
            kind: .warning,
            stage: .validate,
            message: "Review ended on \(calender.startOfDay(for: endDate))."
        )
    }
}
