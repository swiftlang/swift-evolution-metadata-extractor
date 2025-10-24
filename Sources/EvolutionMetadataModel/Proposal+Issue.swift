
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal {
    
    /// Type containing metadata extraction and validation warnings and errors
    ///
    /// The `warnings` and `errors` properties contain instances of `Issue`
    ///
    public struct Issue: Sendable, Hashable, Codable {
        
        /// Kind of issue, warning or error
        public let kind: Kind
        
        /// Numeric code to identify the issue
        public let code: Int
        
        /// Message describing the issue
        public let message: String

        /// Suggestion for addressing the issue
        public let suggestion: String

        public enum Kind: String, Equatable, Sendable, Codable {
            case warning
            case error
        }
        
        public init(kind: Kind, code: Int = 0, message: String, suggestion: String = "") {
            self.kind = kind
            self.code = code
            self.message = message
            self.suggestion = suggestion
        }
    }
}
