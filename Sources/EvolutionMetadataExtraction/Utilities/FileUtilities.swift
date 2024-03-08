
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
    
    static func processDirectory() -> URL? {
        if let commandPath = CommandLine.arguments.first {
            let commandURL = URL(filePath: commandPath)
            return commandURL.deletingLastPathComponent()
        }
        return nil
    }
    
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
