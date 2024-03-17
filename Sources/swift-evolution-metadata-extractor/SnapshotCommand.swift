
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
    
    @Option(name: [.short, .customLong("output-path")], help: Help.Snapshot.Argument.outputPath, transform: ArgumentValidation.Snapshot.output)
    var output: ExtractionJob.Output = ArgumentValidation.Snapshot.defaultOutput
    
    @Flag(name: .shortAndLong, help: Help.Snapshot.Argument.verbose)
    var verbose: Bool = false


    mutating func validate() throws {
        ArgumentValidation.validate(verbose: verbose)
        ArgumentValidation.validateHTTPProxies()
    }


    func run() async throws {
        // Snapshots always pull values from the network and always ignore previous results
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: .network, output: output, ignorePreviousResults: true, toolVersion: RootCommand.toolVersion)
        try await extractionJob.run()
    }
}
