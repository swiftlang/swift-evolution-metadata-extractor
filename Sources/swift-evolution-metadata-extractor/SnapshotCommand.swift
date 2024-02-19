
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
    
    @Option(name: [.short, .customLong("output-path")], help: Help.Snapshot.Argument.outputPath, transform: ArgumentValidation.Snapshot.outputURL)
    var outputURL: URL = URL(filePath: ArgumentValidation.Snapshot.defaultFilename)
    
    @Flag(name: .shortAndLong, help: Help.Snapshot.Argument.verbose)
    var verbose: Bool = false


    mutating func validate() async throws {
        ArgumentValidation.Snapshot.validate(verbose: verbose)
    }


    func run() async throws {
        // Snapshots always pull values from the network and always ignore previous results
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: .network, output: .snapshot(outputURL), ignorePreviousResults: true, toolVersion: RootCommand.configuration.version)
        try await extractionJob.run()
    }
}
