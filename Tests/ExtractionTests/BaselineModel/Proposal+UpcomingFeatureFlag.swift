// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal_v1 {
    
    /// Type representing the upcoming feature flag associated with a proposal.
    public struct UpcomingFeatureFlag: Sendable, Equatable, Codable {
        
        /// The upcoming feature flag
        public let flag: String
        
        public init(flag: String) {
            self.flag = flag
        }
    }
}
