
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

struct ExtractCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: Help.Extract.commandName,
        abstract: Help.Extract.abstract,
        discussion: Help.Extract.discussion
    )
    
    @Option(name: [.short, .customLong("output-path")], help: Help.Extract.Argument.outputPath, transform: ArgumentValidation.Extract.outputURL)
    var outputURL: URL = URL(filePath: ArgumentValidation.Extract.defaultFilename)
    
    @Flag(name: .shortAndLong, help: Help.Extract.Argument.verbose)
    var verbose: Bool = false
    
    @Option(help: Help.Extract.Argument.forceExtract)
    var forceExtract: [String] = []
    var forceAll = false
    var forcedExtractionIDs: [String] = []
    
    @Option(name: .customLong("snapshot-path"), help: Help.Extract.Argument.snapshotPath, transform: ArgumentValidation.Extract.extractionSource)
    var extractionSource: ExtractionJob.Source = .network

    
    mutating func validate() throws {
        ArgumentValidation.Extract.validate(verbose: verbose)
        (forceAll, forcedExtractionIDs) = try ArgumentValidation.Extract.validate(forceExtract: forceExtract)
    }

    
    func run() async throws {
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: extractionSource, output: .metadataJSON(outputURL), ignorePreviousResults: forceAll, forcedExtractionIDs: forcedExtractionIDs, toolVersion: RootCommand.configuration.version)
        try await extractionJob.run()
    }
}
