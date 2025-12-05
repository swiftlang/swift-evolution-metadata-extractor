// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal {
    
    /// Type that represents a tracking bug associated with a proposal.
    public struct TrackingBug: Sendable, Hashable, Codable {
        
        /// Issue ID
        public let id: String
        
        /// Link to issue in issue tracker
        public let link: String

        public init(id: String, link: String) {
            self.id = id
            self.link = link
        }
    }
}
