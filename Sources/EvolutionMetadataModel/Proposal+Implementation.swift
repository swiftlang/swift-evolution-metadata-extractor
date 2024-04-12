
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal {
    
    /// Type of implementation code details  .
    public struct Implementation: Sendable, Equatable, Codable {
        public let account: String
        public let repository: String
        public let type: String
        public let id: String
        
        public init(account: String, repository: String, type: String, id: String) {
            self.account = account
            self.repository = repository
            self.type = type
            self.id = id
        }
    }
}
