
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

extension Proposal {
    public struct Issue: Sendable, Equatable, Codable {
        
        public let kind: Kind
        public let stage: Stage
        public let message: String
        
        public init(kind: Kind, stage: Stage, message: String) {
            self.kind = kind
            self.message = message
            self.stage = stage
        }
        
        public enum Kind: String, Equatable, Sendable, Codable {
            case warning
            case error
        }
        
        public enum Stage: String, Equatable, Sendable, Codable {
            case parse
            case validate
        }
    }
}
