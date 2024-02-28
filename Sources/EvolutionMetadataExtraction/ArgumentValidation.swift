
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
    if verboseEnabled && additionalCondition { print(items, separator: separator, terminator: terminator) }
}
let verboseEnabled: Bool = { VERBOSE_ENABLED }()

extension URLSession {
    static var customSession: URLSession {
        _customSession
    }
}
var _customSession: URLSession = {
    var proxyDictionary: [AnyHashable : Any] = [:]
    
    let environment = ProcessInfo.processInfo.environment
    let httpProxy = environment["http_proxy"] ?? environment["HTTP_PROXY"]
    if let httpProxy, let url = URL(string: httpProxy), let host = url.host, let port = url.port {
        proxyDictionary[kCFNetworkProxiesHTTPEnable] = true
        proxyDictionary[kCFNetworkProxiesHTTPProxy] = host
        proxyDictionary[kCFNetworkProxiesHTTPPort] = port
    }
    
    let httpsProxy = environment["https_proxy"] ?? environment["HTTPS_PROXY"]
    if let httpsProxy, let url = URL(string: httpsProxy), let host = url.host, let port = url.port {
        proxyDictionary[kCFNetworkProxiesHTTPSEnable] = true
        proxyDictionary[kCFNetworkProxiesHTTPSProxy] = host
        proxyDictionary[kCFNetworkProxiesHTTPSPort] = port
    }

    let sessionConfig = URLSessionConfiguration.default
    if !proxyDictionary.isEmpty {
        verbosePrint("Setting proxy dictionary:", terminator: "\n")
        for (key, value) in proxyDictionary {
            verbosePrint("\(key): \(value)", terminator: "\n")
        }
        sessionConfig.connectionProxyDictionary = proxyDictionary
    }
    return URLSession(configuration: sessionConfig)
}()


public enum ArgumentValidation {
    
    public static func validate(verbose: Bool) {
        // Global flag used by global verbosePrint() function. Set as early as possible
        VERBOSE_ENABLED = verbose
        precondition(verboseEnabled == verbose)
                
        if verboseEnabled {
            print("Environment Variables:")
            for (key, value) in ProcessInfo.processInfo.environment {
                print("\(key): \(value)")
            }
        }
        verbosePrint(ProcessInfo.processInfo.environment)
    }
    
    public enum Extract {
        
        public static let defaultFilename = "proposals.json"
        
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
        @Sendable public static func extractionSource(_ snapshotPath: String) throws -> ExtractionJob.Source {
            
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
        @Sendable public static func outputURL(_ outputPath: String) throws -> URL {
            return FileUtilities.outputURLForPath(outputPath, defaultFileName: defaultFilename)
        }
    }
    
    public enum Snapshot {
        
        public static let defaultFilename = "Snapshot.evosnapshot"
        
        //     Transforms --output--path argument into an output URL
        @Sendable public static func outputURL(_ outputPath: String) throws -> URL {
            return FileUtilities.outputURLForPath(outputPath, defaultFileName: defaultFilename)
        }
    }
}
