// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import ArgumentParser

#if canImport(FoundationNetworking)
import FoundationNetworking // Required on Linux
#endif

nonisolated(unsafe) private var VERBOSE_ENABLED: Bool = false // Set once in `validate(verbose:)`, read once for `verboseEnabled`.
func verbosePrint(_ items: Any..., additionalCondition: Bool = true, separator: String = " ", terminator: String = "\n\n") {
    if verboseEnabled && additionalCondition { print(items, separator: separator, terminator: terminator) }
}
let verboseEnabled: Bool = { VERBOSE_ENABLED }()

// MARK: -

public enum ToolVersion {
    static public let version = "0.1.0"
}

// MARK: -

public enum ArgumentValidation {
    
    // Call first in the `validate()` method of each command
    public static func validate(verbose: Bool) {
        VERBOSE_ENABLED = verbose
        precondition(verboseEnabled == verbose)
    }
    
    public static func validateHTTPProxies() {
        _ = URLSession.customized // Reads and validates HTTP Proxy environment variables if present
    }

    @Sendable public static func extractionSource(snapshotURL: URL?, proposalURLs: [URL]) throws -> ExtractionJob.Source {
        if snapshotURL != nil && !proposalURLs.isEmpty {
            throw ValidationError("Cannot provide both a --snapshot-path and <proposal file> arguments")
        } else if let snapshotURL {
            return .snapshot(snapshotURL)
        } else if !proposalURLs.isEmpty {
            return .files(proposalURLs)
        } else {
            return .network
        }
    }
    
    // Transforms file path argument into URL
    @Sendable public static func proposalURL(_ filePath: String) throws -> URL {
        let proposalURL = FileUtilities.expandedAndStandardizedURL(for: filePath)
        guard proposalURL.pathExtension == "md" else {
            throw ValidationError("Proposal file paths must be Markdown files with the path extension '.md'")
        }
        return proposalURL
    }

    // Transforms snapshot-path argument into URL
    @Sendable public static func snapshotURL(_ snapshotPath: String) throws -> URL {

        let snapshotURL: URL
        
        // Check for value 'default' or 'malformed' to use the AllProposals or Malformed snapshot in the test bundle
        if snapshotPath == "default" || snapshotPath == "malformed" {
            guard let processURL = FileUtilities.processDirectory else {
                throw ValidationError("Unable to get path to the swift-evolution-metadata-extractor executable.")
            }
            
            let testBundleName = "swift-evolution-metadata-extractor_ExtractionTests.bundle"
            let testBundleURL = processURL.appending(component: testBundleName)
            guard let testBundle = Bundle(url: testBundleURL) else {
                let snapshotDescription = (snapshotPath == "default") ? "default snapshot" : "snapshot of malformed proposals"
                throw ValidationError("The test bundle '\(testBundleName)' must be located in the same directory as the swift-evolution-metadata-extractor executable.\n\nTo use the \(snapshotDescription), execute `swift test` or the Xcode test action to generate the test snapshots for the package.\n")
            }
            
            let snapshotName = (snapshotPath == "default") ? "AllProposals" : "Malformed"
            guard let url = testBundle.url(forResource: snapshotName, withExtension: "evosnapshot", subdirectory: "Resources") else {
                let snapshotDescription = (snapshotPath == "default") ? "default snapshot" : "snapshot of malformed proposals"
                throw ValidationError("\(snapshotPath).evosnapshot does not exist.\n\nTo use the \(snapshotDescription), execute `swift test` or the Xcode test action to generate the test snapshots for the package.\n")
            }
            snapshotURL = url
        } else {
            snapshotURL = FileUtilities.expandedAndStandardizedURL(for: snapshotPath)
        }
        
        guard snapshotURL.pathExtension == "evosnapshot" else {
            throw ValidationError("Snapshot must be a directory with 'evosnapshot' extension")
        }
        
        do {
            guard let isDirectory = try snapshotURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory else {
                throw ValidationError("Snapshot must be a directory with 'evosnapshot' extension")
            }
        } catch CocoaError.fileReadNoSuchFile {
            throw ValidationError("Directory does not exist at path: '\(snapshotPath)'")
        } catch {
            throw ValidationError("Snapshot must be a directory with 'evosnapshot' extension")
        }
        return snapshotURL
    }
    
    public enum Extract {
        
        public static let defaultFilename = "evolution.json"
        public static let defaultOutput: ExtractionJob.Output = .metadataJSON(URL(filePath: defaultFilename))
        
        static public func validate(forceExtract: [String]) throws -> (forceAll: Bool, forcedExtractionIDs: [String]) {
            
            var forceAll = false
            var forcedExtractionIDs: [String] = []
            
            if !forceExtract.isEmpty {
                for arg in forceExtract {
                    if arg == "all" {
                        forceAll = true
                    } else if arg.contains(/^SE-\d\d\d\d$/){
                        forcedExtractionIDs.append(arg)
                    } else {
                        throw ValidationError("Valid --force-extraction values are 'all' and proposal ids of the form 'SE-NNNN'")
                    }
                }
                if forceAll && !forcedExtractionIDs.isEmpty {
                    // Argument validation warnings are printed whether verbose is set or not.
                    print("Warning: Using --force-extract with value 'all' and proposal IDs \(forcedExtractionIDs.formatted()). All proposals will be force extracted. ")
                } else {
                    verbosePrint("Force Extract All:", forceAll, additionalCondition: forceAll)
                    verbosePrint("Force Extract Proposals:", forcedExtractionIDs.formatted(), additionalCondition: !forcedExtractionIDs.isEmpty)
                }
            }
                        
            return (forceAll, forcedExtractionIDs)
        }
        
        // Transforms --output--path argument into an output value
        @Sendable public static func output(_ outputPath: String) throws -> ExtractionJob.Output {
            if outputPath == "none" { .none }
            else { .metadataJSON(FileUtilities.outputURL(for: outputPath, defaultFileName: defaultFilename)) }
        }
    }
    
    public enum Snapshot {
        
        public static let defaultFilename = "Snapshot.evosnapshot"
        public static let defaultOutput: ExtractionJob.Output = .snapshot(URL(filePath: defaultFilename))

        // Transforms --output--path argument into an output value
        @Sendable public static func output(_ outputPath: String) throws -> ExtractionJob.Output {
            if outputPath == "none" { .none }
            else if outputPath == "stdout" { throw ValidationError("The output path 'stdout' is not valid for the snapshot command")}
            else { .snapshot(FileUtilities.outputURL(for: outputPath, defaultFileName: defaultFilename)) }
        }
    }
}
