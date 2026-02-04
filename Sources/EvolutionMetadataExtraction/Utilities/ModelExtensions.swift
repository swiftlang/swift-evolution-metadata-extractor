// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

extension EvolutionMetadata {

    var hasCurrentToolVersion: Bool { toolVersion == ToolVersion.version }
    var hasCurrentSchemaVersion: Bool { schemaVersion == EvolutionMetadata.schemaVersion }
    var hasCurrentMetadataVersions: Bool { hasCurrentToolVersion && hasCurrentSchemaVersion }

    var jsonRepresentation: Data {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            let adjustedData = JSONRewriter.applyRewritersToJSONData(rewriters: [JSONRewriter.prettyPrintVersions], data: data)
            return adjustedData
        }
    }

    var hasErrors: Bool { proposals.contains { $0.hasErrors } }

    var validationReport: String {
        var report = """
            Swift Evolution Validation Report
            Generated: \(creationDate)
            Tool Version: \(toolVersion)\n\n
            """
        let errorProposals = proposals.filter { $0.hasIssues }
        
        if errorProposals.isEmpty {
            report += "NO ISSUES FOUND\n"
        } else {
            report += "ISSUES FOUND\n\n"
            report = errorProposals.reduce(into: report) { $0 += $1.validationReport + "\n" }
        }
        return report
    }
}

// MARK: -

extension Proposal {

    var hasErrors: Bool {
        if let errors, !errors.isEmpty { true } else { false }
    }
    var hasWarnings: Bool {
        if let warnings, !warnings.isEmpty { true } else { false }
    }
    var hasIssues: Bool { hasWarnings || hasErrors }

    var validationReport: String {
        var report: String = ""
        if hasErrors || hasWarnings {
            let adjustedID = id.isEmpty ? "<Missing ID>" : id
            let adjustedTitle = title.isEmpty ? "<Missing Title>" : "'\(title)'"
            report += (id.isEmpty && title.isEmpty) ? "<Missing ID & Title>" : "\(adjustedID) \(adjustedTitle)"
            if !link.isEmpty { report += "\n" + link }
            report += "\n\n"

            if hasErrors, let errors {
                report += issuesReport(heading: "ERRORS", issues: errors) + "\n"
            }
            if hasWarnings, let warnings {
                report += issuesReport(heading: "WARNINGS", issues: warnings) + "\n"
            }
        }
        return report
    }

    private func issuesReport(heading: String, issues: [Proposal.Issue]) -> String {
        var report = "\t\(heading)\n"
        for issue in issues {
            report += "\t\(issue.message)\n"
        }
        return report
    }
}
