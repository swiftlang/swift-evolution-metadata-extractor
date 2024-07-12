
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser
import EvolutionMetadataExtraction

@main
struct RootCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: Help.Root.commandName,
        abstract: Help.Root.abstract,
        usage: Help.Root.usage,
        discussion: Help.Root.discussion,
        version: ToolVersion.version,
        subcommands: [ExtractCommand.self, SnapshotCommand.self],
        defaultSubcommand: ExtractCommand.self
    )
}
