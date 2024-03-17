
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser

enum Help {
    
    enum Root {
        static let commandName = "swift-evolution-metadata-extractor"
        
        static let abstract = "Extracts and validates metadata from Swift evolution proposals and generates a summary JSON file."
        
        static let usage = """
        swift-evolution-metadata-extractor <subcommand>
        
        swift-evolution-metadata-extractor [--output-path <output-path>] [--verbose] [--force-extract <force-extract> ...] [--snapshot-path <snapshot-path>]
        """
        
        static let discussion =  """
        Running with no arguments will read from the swift-evolution repository, extract metadata and write a "proposals.json" file to the current directory.
        """
    }
    
    // Contains command help strings shared by two or more commands
    enum Shared {
        enum Argument {
            static let outputPath: ArgumentHelp = "Path to output file. Use value 'none' to suppress output."
            static let snapshotPath: ArgumentHelp = "Path to a local .evosnapshot directory for testing during development. Use 'default' to use AllProposals snapshot in the test bundle."
            static let verbose: ArgumentHelp = "Verbose output"
        }
    }
    
    enum Extract {
        static let commandName = "extract"
        
        static let usage = """
        \(commandName) --force-extraction all
        \(commandName) --force-extraction SE-0344 --force-extraction SE-0134
        \(commandName) --output-path asdf/proposals.json
        """
        
        static let abstract = "Extracts metadata from Swift evolution proposals and generates a summary JSON file."
        
        static let discussion =  """
        Running with no arguments will read from the swift-evolution repository, extract metadata and write a "proposals.json" file to the current directory.
        """
        
        enum Argument {
            static let forceExtract: ArgumentHelp = "Forces extraction of all or specified proposals. Valid values are 'all' or `SE-XXXX'"
        }
    }
    
    enum Snapshot {
        static let commandName = "snapshot"
        
        static let abstract = "Creates a snapshot of swift-evolution input files and expected results for development and testing."
        
        static let discussion =  """
            Running with no arguments will read from the swift-evolution repository, extract metadata and write an '.evosnapshot' directory to the current directory.
            """
    }
}
