
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

extension Proposal {
    
    /// Type that represents a person associated with a proposal.
    ///
    /// The `authors` and `reviewManagers` properties contain instances of `Person`
    ///
    public struct Person: Sendable, Hashable, Codable {

        /// Name of the person
        public let name: String

        /// URL string of the GitHub profile of the person. May be an empty string.
        public let link: String
        
        public init(name: String = "", link: String = "") {
            self.name = name
            self.link = link
        }
    }
}
