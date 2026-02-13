// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import Markdown
import EvolutionMetadataModel

struct StatusExtractor: MarkupWalker, ValueExtractor {
    
    private var source: HeaderFieldSource
    private var extractionDate: Date = Date()
    init(source: (source: HeaderFieldSource, extractionDate: Date)) {
        self.source = source.source
        self.extractionDate = source.extractionDate
    }
    
    private var issues = IssueWrapper()
    var status: Proposal.Status? = nil
    
    mutating func extractValue() -> ExtractionResult<Proposal.Status> {
        
        // If 'Status' field not found, report
        if let headerField = source["Status"] {
            visit(headerField)
        }
        
        // This checks both that the field is found and is successfully extracted
        if status == nil {
            issues.reportIssue(.missingStatus, source: source)
        }
        return ExtractionResult(value: status, warnings: issues.warnings, errors: issues.errors)
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        guard let statusElement = strong.child(at: 0) as? Text else {
            // VALIDATION ENHANCEMENT: Add warning or error malformed / misformatted status
            return
        }
        guard let statusMatch = statusElement.string.firstMatch(of: /(?<status>.*)($|\s\((?<details>.*)\))/.repetitionBehavior(.reluctant)) else {
            // VALIDATION ENHANCEMENT: Add warning or error malformed / misformatted status
            return
        }
        let statusString = String(statusMatch.status)
        var version = ""
        var start = ""
        var end = ""
        
        if statusString.contains(/Implemented/.ignoresCase()) {
            version = StatusExtractor.versionForString(String(statusMatch.details ?? ""))
        }
        else if statusString.contains(/(Scheduled for|Active) Review/.ignoresCase()) {
            if let result = StatusExtractor.datesForString(String(statusMatch.details ?? ""), processingDate: extractionDate) {
                start = result.start
                end = result.end
            } else {
                issues.reportIssue(.missingOrInvalidReviewDates, source: source)
            }
        }
        
        if let rawStatus = Proposal.Status(name: statusString, version: version, start: start, end: end) {
            status = rawStatus
        } else {
            issues.reportIssue(.missingOrInvalidStatus, source: source)
            status = .statusExtractionFailed
        }
    }

    static func versionForString(_ fullVersionString: String) -> String {
        guard !fullVersionString.isEmpty else {
            return "none" // If empty string, return 'none' as a sentinel value
        }
        
        let version: String
        // Strip out 'Swift ' if it exists
        // VALIDATION ENHANCEMENT: Potentially normalize the few proposals that don't list Swift and add validation error
        let swiftStrippedString: String
        if let index = fullVersionString.firstRange(of: "Swift ") {
            let substring = fullVersionString[index.upperBound...]
            swiftStrippedString = String(substring)
        } else {
            swiftStrippedString = fullVersionString
        }
        
        // Handle the one case where there is a long comment after the version number
        // Would probably want to test this and error out anyway
        let substrings = swiftStrippedString.split(separator: " ")
        //            let version: String
        if substrings.isEmpty {
            version = ""
        } else {
            version = String(substrings[0])
        }
        
        return version
    }
    
    // The processing date is typically the default value of 'now', the date of the processing
    // For testing, a different processing date can be provided
    // VALIDATION ENHANCEMENT: A date range like (Apr 29 - May 3) will parse incorrectly by finding May and thinking both dates are in May
    // VALIDATION ENHANCEMENT: Something like (4 - 13 April 2022) will parse correctly. Should probably validate to the expected format
    static func datesForString(_ string: String, processingDate: Date) -> (start: String, end: String)? {
        
        // used in two case blocks; hoisting up here for reuse
        let integerMatcher = /\d+/
        
        let monthMatcher = /January|February|March|April|May|June|July|August|September|October|November|December/.ignoresCase()
        
        let monthMatches = string.matches(of: monthMatcher)
        
        // For a date range, only 1 or 2 month values are valid
        guard monthMatches.count != 0 && monthMatches.count < 3 else {
            // VALIDATION ENHANCEMENT
            //            print("ERROR: '\(string)': Unexpected month count of \(monthMatches.count)")
            return nil
        }
        
        let startMonth = String(monthMatches[0].0)
        let endMonth = monthMatches.count == 2 ? String(monthMatches[1].0) : startMonth
        //        print(startMonth, endMonth)
        
        // Only interested in numbers of one or two digits
        let dayMatches = string.matches(of: integerMatcher).filter { $0.count <= 2 }
        guard dayMatches.count == 2 else {
            // VALIDATION ENHANCEMENT
//            print("ERROR: '\(string)': Unexpected day count of \(dayMatches.count)")
            return nil
        }

        let (startDay, endDay) = (String(dayMatches[0].0), String(dayMatches[1].0))
        
        // Specify GMT time zone so parsed date is normalized to midnight GMT
        // Setting explicit locale to ensure repeatable results
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM' 'd' 'yyyy"
        formatter.timeZone = TimeZone.gmt
        formatter.locale = Locale.en_US_POSIX
        
        let presentFormatter = DateFormatter()
        presentFormatter.dateFormat = "y"
        let presentYear: Int = Int(presentFormatter.string(from: processingDate))!
        
        guard
            let startDate = formatter.date(from: "\(startMonth) \(startDay) \(presentYear)"),
            let endDate = formatter.date(from: "\(endMonth) \(endDay) \(presentYear)")
        else {
            return nil // sort of a diagnostic-less error here, but it'll show up as an invalid date
        }

        // VALIDATION ENHANCEMENT: This rationale is no longer valid. Proposals now include the year in date ranges.
        // VALIDATION ENHANCEMENT: For purposes of transition from legacy to new tool, keep logic the same
        // VALIDATION ENHANCEMENT: Consider updating after transition
        /*
        Discussion of rationale:

        SE proposal dates, in our format, lack a year specifier.
        If someone schedules a review from March 2-6 in 2014,
        then forgets to update it until 2015, this code will
        assume that the review should take place from March 2-6 in 2015 (or the current year)

        Since we lack a year specifier, we also need to consider mistakes in
        date entry vs. "wrapping" dates, like a Dec 31 - Jan 4 date.

        Here, I'm assuming that any wrapping date is valid, and assuming
        that the intent is to wrap/span to the next year.

        Alternatively, we could detect if the difference is, say > 1 month,
        then warn/complain about the span.
        */
        
        var wrappedEndDate = endDate
        if wrappedEndDate < startDate {
            wrappedEndDate = formatter.date(from: "\(endMonth) \(endDay) \(presentYear + 1)")!
        }
        
        // Specify explicit GMT time zone and 'en_US_POSIX' locale
        let dateFormatStyle = Date.ISO8601FormatStyle(timeZone: TimeZone.gmt).locale(Locale.en_US_POSIX)
        return (startDate.formatted(dateFormatStyle), wrappedEndDate.formatted(dateFormatStyle))
    }
}

extension Proposal.Status {
    // VALIDATION ENHANCEMENT: Consider normalizing capitalization of statuses and validating correct capitalization
    public init?(name: String, version: String = "", start: String = "", end: String = "", reason: String = "") {
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
            case "Error".lowercased(): self = .error(reason: reason)
            // VALIDATION ENHANCEMENT: The following are non-standard statuses that are in current proposals
            // VALIDATION ENHANCEMENT: The mapped values match the legacy tool implemenation
            // VALIDATION ENHANCEMENT: In the future may want to formalize or normalize
            case "Accepted with modifications".lowercased(): self = .accepted
            case "Partially implemented".lowercased(): self = .implemented(version: version)
            case "Implemented with Modifications".lowercased(): self = .implemented(version: version)
            default: return nil
        }
    }
}
