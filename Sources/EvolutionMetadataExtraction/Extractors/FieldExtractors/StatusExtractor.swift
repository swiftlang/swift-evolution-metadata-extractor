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
            if let detailsString = statusMatch.details.map(String.init) {
                let (versionString, diagnostics) = StatusExtractor.versionResultForString(detailsString)
                if let versionString {
                    version = versionString
                }
                if versionString == nil || !diagnostics.isEmpty {
                    issues.reportIssue(.malformedImplementationVersion(source: detailsString, diagnostics: diagnostics), source: source)
                }
            } else {
                issues.reportIssue(.missingOrInvalidImplementedVersion, source: source)
            }
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

    nonisolated(unsafe) static private let versionRegex = /Swift (?<version>(?:[1-9]\.[0-9]+(?:\.[0-9]+)?)|Next)/

    // This method makes a best effort attempt to extract a valid version
    // The return value can include both a version and diagnostics
    // if diagnostics, use diagnostics in creating malformed version error with additional suggestion
    // if version, version is valid and should be used
    // if version is nil with no diagnostics, no valid version found and return a basic malformed version error
    static func versionResultForString(_ fullVersionString: String) -> (version: String?, diagnostics: DiagnosticMessageSet) {
        var versionString: String? = nil
        var diagnostics: DiagnosticMessageSet = []

        if let versionMatch = fullVersionString.wholeMatch(of: versionRegex) {
            versionString = String(versionMatch.version)
        }
        // SE-0273 adds notes within the parenthesis, continue extracting the version
        else if let versionMatch = fullVersionString.firstMatch(of: versionRegex){
            versionString = String(versionMatch.version)
            diagnostics.insert(.extraText)
        }
        // Use lenient regex to diagnose common issues
        else {
            let results = lenientVersionResultForString(fullVersionString)
            versionString = results.version
            diagnostics.formUnion(results.diagnostics)
        }

        return (versionString, diagnostics)
    }

    // Lenient regex to diagnose errors
    nonisolated(unsafe) static private let lenientVersionRegex = /(?<prefix>(?<swift>[Ss]wift) )?(?<version>(?:(?<majorVersion>[1-9][0-9]*)(?<minorPatchVersion>\.[0-9]*(?:\.[0-9]+)?)?)|[Nn]ext)/

    // This method uses more lenient pattern matching to diagnose common issues.
    // By the time this method is called, the version string has already failed strict matching.
    // If a valid version can be extracted, it is reported.
    private static func lenientVersionResultForString(_ fullVersionString: String) -> (version: String?, diagnostics: DiagnosticMessageSet) {
        var versionString: String? = nil
        var diagnostics: DiagnosticMessageSet = []

        // Use lenient regex to diagnose common issues
        if let versionMatch = fullVersionString.firstMatch(of: lenientVersionRegex) {
            var validVersion: String? = nil

            // If a numeric version is found, check for issues
            if let majorVersion = versionMatch.majorVersion {
                var versionIssueFound = false

                if majorVersion.count > 1 {
                    versionIssueFound = true
                    diagnostics.insert(.majorVersionTooLarge)
                }

                if versionMatch.minorPatchVersion == nil {
                    versionIssueFound = true
                    diagnostics.insert(.minorVersionMissing)
                }

                if !versionIssueFound {
                    validVersion = String(versionMatch.version)
                }
            }

            if versionMatch.version == "Next" {
                validVersion = String(versionMatch.version)
            }

            if versionMatch.version == "next" {
                validVersion = "Next"
                diagnostics.insert(.nextMiscapitalized)
            }

            if versionMatch.prefix == nil {
                diagnostics.insert(.swiftMissing)
            }

            if versionMatch.swift == "swift" {
                diagnostics.insert(.swiftMiscapitalized)
            }

            if let majorVersion = versionMatch.majorVersion, majorVersion.count > 1 {
                diagnostics.insert(.majorVersionTooLarge)
            }

            // If a valid version was found report it, even if there are other issues
            if let validVersion {
                versionString = validVersion
            }
        }

        return (versionString, diagnostics)
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
