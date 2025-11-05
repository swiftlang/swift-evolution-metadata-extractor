
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

enum FileUtilities {
    
    static func outputURLForPath(_ path: String, defaultFileName: String) -> URL {
        
        var url = expandedAndStandardizedURL(for: path)
        
        // If no path extension, take intent to be a directory and append the default file name
        if url.pathExtension.isEmpty {
            url = url.appending(component: defaultFileName)
        } else {
            // Warn if output path has a different file extension
            let defaultFileExtension = URL(filePath: defaultFileName).pathExtension
            if defaultFileExtension != url.pathExtension {
                print("WARNING: Specified filename '\(url.lastPathComponent)' does not have the expected extension '\(defaultFileExtension)'")
            }
        }
        
        return url
}

    private static func expandTildeInPath(from path: String) -> String {
        // maybe check if tilde appears multiple times?
        return path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    static func expandedAndStandardizedURL(for path: String) -> URL {
        let fullPath = expandTildeInPath(from: path)
        return URL(filePath: fullPath).standardizedFileURL
    }
    
    static let processDirectory: URL? = {
        if let commandPath = CommandLine.arguments.first {
            let commandURL = URL(filePath: commandPath)
            return commandURL.deletingLastPathComponent()
        }
        return nil
    }()
    
    static func decode<T: Decodable>(_ type: T.Type, from fileURL: URL, required: Bool = false) throws -> T? {
        do { let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let value = try decoder.decode(type, from: data)
            return value
        } catch let error as CocoaError {
            // Missing file is expected on occassion
            if error.code == CocoaError.fileReadNoSuchFile && !required {
                return nil
            }
            else { throw error }
        } catch {
            throw error
        }
    }

}

// A mechanism for adjusting the JSON produced by Codable
// Currently used to:
//   - Pretty print the array of implementation versions
//   - Add the leading dot in status state values for legacy file

enum JSONRewriter {
    
    static func applyRewritersToJSONData(rewriters: [(String) -> String], data: Data) -> Data {
        let sourceString = String(decoding: data, as: UTF8.self)
        var rewrittenString = sourceString
        for rewriter in rewriters {
            rewrittenString = rewriter(rewrittenString)
        }
        return Data(rewrittenString.utf8)
    }
    
    // Temporary shim during transition period
    // Add the leading dot in status state values for legacy format
    static func legacyStatusRewriter(_ sourceString: String) -> String {
        var rewrittenString: String = ""
        for line in sourceString.split(separator: "\n") {
            if let match = line.firstMatch(of:/(\s*"state" : ")(.*)(",?)/) {
                rewrittenString += match.1 + "." + match.2 + match.3 + "\n"
            } else {
                rewrittenString += line + "\n"
            }
        }
        return rewrittenString
    }
    
    static func prettyPrintVersions(_ sourceString: String) -> String {
        
        let versionsListRegex = /"implementationVersions" : \[\n(?<versionsList>(?:\s*"(?:(?:(?:\d+\.)+\d+)|Next)",?\n)*)/
        var processedString: String
        
        if let match = sourceString.firstMatch(of: versionsListRegex) {
            // Copy versions list string
            var versionsString = String(match.output.versionsList)
            
            // Remove newlines and spaces for every nth item in versions array
            let maxPerLine = 10
            let maxReplacements = maxPerLine - 1
            let endlineRegex = /\n\s+/ // One or more whitespace intentionally prevents last item from matching
            
            var first = true
            var startIndex = versionsString.startIndex
            while let foundRange = versionsString[startIndex..<versionsString.endIndex].firstRange(of: endlineRegex) {
                if first { first = false } // Find and replace endline of first list item
                else { startIndex = foundRange.upperBound } // Skip the next found endline leaving the line break in place
                let subrange = startIndex..<versionsString.endIndex
                versionsString = versionsString.replacing(endlineRegex, with: " ", subrange: subrange, maxReplacements: maxReplacements)
            }
            
            // Replace versions list
            let replacementRange = match.output.versionsList.startIndex..<match.output.versionsList.endIndex
            processedString = sourceString.replacingCharacters(in: replacementRange, with: versionsString)
            
            processedString.replace("\n\n", with: "\n") // Replace blank lines in entire string

        } else {
            processedString = sourceString
        }
        processedString.append("\n") // Add newline at end of string
        return processedString
    }
}
