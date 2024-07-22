
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal_v1 {
    
    /// Type that represents a discussion abou a proposal.
    public struct Discussion: Sendable, Codable, Equatable {

        /// Name of the discussion
        public let name: String

        /// URL string to the discussion
        public let link: String
        
        public init(name: String = "", link: String = "") {
            self.name = name
            self.link = link
        }
    }
}
