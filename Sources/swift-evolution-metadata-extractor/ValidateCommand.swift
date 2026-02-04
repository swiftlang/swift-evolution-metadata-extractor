// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import ArgumentParser
import EvolutionMetadataExtraction

struct ValidateCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: Help.Validate.commandName,
        abstract: Help.Validate.abstract,
        discussion: Help.Validate.discussion
    )

    @Option(name: [.short, .customLong("output-path")], help: Help.Shared.Argument.outputPath, transform: ArgumentValidation.Validate.output)
    var output: ExtractionJob.Output = ArgumentValidation.Validate.defaultOutput

    @Option(name: .customLong("snapshot-path"), help: Help.Shared.Argument.snapshotPath, transform: ArgumentValidation.snapshotURL)
    var snapshotURL: URL?
    var extractionSource: ExtractionJob.Source = .network

    @Flag(name: .shortAndLong, help: Help.Shared.Argument.verbose)
    var verbose: Bool = false

    @Argument(help: Help.Shared.Argument.proposalFiles, transform: ArgumentValidation.proposalURL)
    var proposalURLs: [URL] = []

    mutating func validate() throws {
        ArgumentValidation.validate(verbose: verbose)
        ArgumentValidation.validateHTTPProxies()
        extractionSource = try ArgumentValidation.extractionSource(snapshotURL: snapshotURL, proposalURLs: proposalURLs)
    }


    func run() async throws {
        // Always ignore previous results when generating a validation report
        let extractionJob = try await ExtractionJob.makeExtractionJob(source: extractionSource, output: output, ignorePreviousResults: true)
        try await extractionJob.run()
    }
}
