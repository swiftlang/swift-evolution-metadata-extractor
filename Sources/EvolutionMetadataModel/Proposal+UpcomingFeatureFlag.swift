
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal {
    
    /// Type representing the upcoming feature flag associated with a proposal.
    public struct UpcomingFeatureFlag: Sendable, Equatable, Codable {
        
        /// The upcoming feature flag
        public let flag: String
        
        /// The Swift version when this flag became available.
        ///
        /// Only present if the Swift version is different than the implemenation version of the proposal.
        public let available: String?
        
        /// Swift language version (language mode) where the flag is always enabled and therefore no longer necessary.
        ///
        /// Only present for publicly announced language versions.
        public let enabledInLanguageVersion: String?
        
        public init(flag: String, available: String?, enabledInLanguageVersion: String?) {
            self.flag = flag
            self.available = available
            self.enabledInLanguageVersion = enabledInLanguageVersion
        }
    }
}
