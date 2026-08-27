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
    init(source: HeaderFieldSource) { self.source = source }

    private var issues = IssueWrapper()
    var status: Proposal.Status? = nil
    
    mutating func extractValue() -> ExtractionResult<Proposal.Status> {
        
        // If 'Status' field not found, report
        if let headerField = source["Status"] {
            visit(headerField)
            if status == nil {
                issues.reportIssue(.invalidStatus, source: source)
            }
        } else {
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
            if let result = datesForString(String(statusMatch.details ?? "")) {
                start = result.start
                end = result.end
            } else {
                issues.reportIssue(.missingOrInvalidReviewDates, source: source)
            }
        }
        
        if let rawStatus = Proposal.Status(name: statusString, version: version, start: start, end: end) {
            status = rawStatus
        } else {
            issues.reportIssue(.invalidStatus, source: source)
            status = .statusExtractionFailed
        }
    }

// MARK: -

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

// MARK: -

    // Returning nil from this method signifies a malformed date range string (the regex does not match)
    // The caller is responsible for reporting the error
    // Note that this function will return successfully extracted dates, even if there are
    // issues with the dates extracted, such as an end date earlier than a start date
    // These issues are reported by this method, but do no prevent return of the extracted dates
    mutating func datesForString (_ string: String) -> (start: String, end: String)? {
        if let (startDate, endDate) = StatusExtractor.datesForString(string) {

            // Ensure end date is later than start date
            let calendar = Calendar(identifier: .gregorian)
            if startDate > endDate {
                issues.reportIssue(.invalidReviewPeriodDateRange, source: source)
            } else if calendar.isDate(startDate, equalTo: endDate, toGranularity: .day) {
                issues.reportIssue(.singleDayReviewPeriod, source: source)
            }

            // Specify explicit GMT time zone and 'en_US_POSIX' locale
            let dateFormatStyle = Date.ISO8601FormatStyle(timeZone: TimeZone.gmt).locale(Locale.en_US_POSIX)
            return (startDate.formatted(dateFormatStyle), endDate.formatted(dateFormatStyle))

        } else {
            return nil
        }
    }

    // Does not allow 3-letter month abbreviations
    // Currently in use
    nonisolated(unsafe) static private let dateRegex = /(?<startMonth>January|February|March|April|May|June|July|August|September|October|November|December)(?: )(?<startDay>(?:[1-3][0-9])|(?:0?[1-9]))(?:, (?<startYear>2[0-9]{3}))?(?:(?: [-–] )|(?:[-–])|(?:\.\.\.))(?:(?<endMonth>January|February|March|April|May|June|July|August|September|October|November|December) )?(?<endDay>(?:[1-3][0-9])|(?:0?[1-9]))(?:, (?<endYear>2[0-9]{3}))/

    // Allows 3-letter month abbreviations
    // Currently unused
    nonisolated(unsafe) static private let alternateDateRegex = /(?<startMonth>(?:Jan(?:uary)?)|(?:Feb(?:ruary)?)|(?:Mar(?:ch)?)|(?:Apr(?:il)?)|(?:May)|(?:Jun(?:e)?)|(?:Jul(?:y)?)|(?:Aug(?:ust)?)|(?:Sep(?:tember)?)|(?:Oct(?:ober)?)|(?:Nov(?:ember)?)|(?:Dec(?:ember)?))(?: )(?<startDay>(?:[1-3][0-9])|(?:0?[1-9]))(?:, (?<startYear>2[0-9]{3}))?(?:(?: [-–] )|(?:[-–])|(?:\.\.\.))(?:(?<endMonth>(?:Jan(?:uary)?)|(?:Feb(?:ruary)?)|(?:Mar(?:ch)?)|(?:Apr(?:il)?)|(?:May)|(?:Jun(?:e)?)|(?:Jul(?:y)?)|(?:Aug(?:ust)?)|(?:Sep(?:tember)?)|(?:Oct(?:ober)?)|(?:Nov(?:ember)?)|(?:Dec(?:ember)?)) )?(?<endDay>(?:[1-3][0-9])|(?:0?[1-9]))(?:, (?<endYear>2[0-9]{3}))/

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    // This method focuses only on extracting the start and end dates from the content string
    // It does not perform additional validation on the dates
    // This allows the 'Good dates' / 'Bad dates' tests to use this function directly without reporting
    // proposal-specific issues
    static func datesForString(_ string: String) -> (start: Date, end: Date)? {

        func monthNumber(for str: String) -> Int? {
            if let index = months.firstIndex(of: str) { index + 1 } else { nil }
        }

        if let dateMatch = string.firstMatch(of: dateRegex) {

            let startDay = Int(String(dateMatch.startDay))!
            let endDay = Int(String(dateMatch.endDay))!

            let startMonth = monthNumber(for: String(dateMatch.startMonth.prefix(3)))!
            let endMonth = if let rawEndMonth = dateMatch.endMonth {
                monthNumber(for: String(rawEndMonth.prefix(3)))!
            } else {
                startMonth
            }

            let endYear = Int(String(dateMatch.endYear))!
            let startYear = if let rawStartYear = dateMatch.startYear {
                Int(String(rawStartYear))!
            } else {
                endYear
            }

            let calendar = Calendar(identifier: .gregorian)
            
            let startDateComponents = DateComponents(calendar: calendar, timeZone: TimeZone.gmt, year: startYear, month: startMonth, day: startDay)
            let startDate = startDateComponents.date!

            let endDateComponents = DateComponents(calendar: calendar, timeZone: TimeZone.gmt, year: endYear, month: endMonth, day: endDay)
            let endDate = endDateComponents.date!

            return (startDate, endDate)

        } else {
            return nil
        }
    }
}

// MARK: -

// Failable initializer validates that a string is a supported status value
// For nil returns, the caller is reponsible for reporting the issue
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
            // TEMPORARY: Treat 'Expired' as Rejected until addition is confirmed and dashboard is updated
            case "Expired".lowercased(): self = .rejected
            default: return nil
        }
    }
}
