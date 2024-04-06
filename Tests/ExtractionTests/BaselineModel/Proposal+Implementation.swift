
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

extension Proposal_v1 {
    public struct Implementation: Sendable, Equatable, Codable {
        public let account: String
        public let id: String
        public let repository: String
        public let type: String
        
        public init(account: String, id: String, repository: String, type: String) {
            self.account = account
            self.id = id
            self.repository = repository
            self.type = type
        }
    }
}
