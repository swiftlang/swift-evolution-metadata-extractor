
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import ArgumentParser

var VERBOSE_ENABLED: Bool = false
func verbosePrint(_ items: Any..., additionalCondition: Bool = true, separator: String = " ", terminator: String = "\n\n") {
    if VERBOSE_ENABLED && additionalCondition { print(items, separator: separator, terminator: terminator) }
}
var verboseEnabled: Bool { VERBOSE_ENABLED }

public enum ArgumentValidation {
    
    public enum Extract {
        public static let defaultFilename = "proposals.json"
        
        public static func validate(verbose: Bool) {
            VERBOSE_ENABLED = verbose // Global flag used by global verbosePrint() function. Set as early as possible
        }
        
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
        
        // Transforms snapshot-path argument into .snapshot(URL) extraction source
        public static func extractionSource(_ snapshotPath: String) throws -> ExtractionJob.Source {
            
            let snapshotURL = FileUtilities.expandedAndStandardizedURL(for: snapshotPath)
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
            return .snapshot(snapshotURL)
        }
        
    //     Transforms --output--path argument into an output URL
        public static func outputURL(_ outputPath: String) throws -> URL {
            return FileUtilities.outputURLForPath(outputPath, defaultFileName: defaultFilename)
        }
    }
    
    public enum Snapshot {
        public static let defaultFilename = "Snapshot.evosnapshot"
        
        public static func validate(verbose: Bool) {
            VERBOSE_ENABLED = verbose // Global flag used by global verbosePrint() function. Set as early as possible
        }
        
        //     Transforms --output--path argument into an output URL
        public static func outputURL(_ outputPath: String) throws -> URL {
            return FileUtilities.outputURLForPath(outputPath, defaultFileName: defaultFilename)
        }
    }
}
