// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal_v1 {
    
    /// Type representing a repository code change of a proposal implementation
    public struct Implementation: Sendable, Equatable, Codable {
        
        /// The GitHub account containing the implementation
        public let account: String
        
        /// The repository containing the implementation
        public let repository: String
        
        /// The type of implementation code change, value is either 'push' or 'commit'
        public let type: String
        
        /// The id of the implementation code change
        public let id: String
        
        public init(account: String, repository: String, type: String, id: String) {
            self.account = account
            self.repository = repository
            self.type = type
            self.id = id
        }
    }
}
