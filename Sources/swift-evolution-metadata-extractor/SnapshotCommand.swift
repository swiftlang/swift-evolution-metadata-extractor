
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import ArgumentParser
import EvolutionMetadataExtraction

struct SnapshotCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: Help.Snapshot.commandName,
        abstract: Help.Snapshot.abstract,
        discussion: Help.Snapshot.discussion
    )
    
    @Option(name: [.short, .customLong("output-path")], help: Help.Shared.Argument.outputPath, transform: ArgumentValidation.Snapshot.output)
    var output: ExtractionJob.Output = ArgumentValidation.Snapshot.defaultOutput
    
    @Flag(name: .shortAndLong, help: Help.Shared.Argument.verbose)
    var verbose: Bool = false
    
    @Option(name: .customLong("snapshot-path"), help: Help.Shared.Argument.snapshotPath, transform: ArgumentValidation.extractionSource)
    var extractionSource: ExtractionJob.Source = .network


    mutating func validate() throws {
        ArgumentValidation.validate(verbose: verbose)
        ArgumentValidation.validateHTTPProxies()
    }


    func run() async throws {
        // Always ignore previous results when generating a snapshot
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: extractionSource, output: output, ignorePreviousResults: true)
        try await extractionJob.run()
    }
}
