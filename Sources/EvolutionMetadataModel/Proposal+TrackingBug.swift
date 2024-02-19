
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

extension Proposal {
    public struct TrackingBug: Sendable, Equatable, Codable {
        public let assignee: String
        public let id: String
        public let link: String
        public let radar: String
        public let resolution: String
        public let status: String
        public let title: String
        public let updated: String
        
        public init(id: String, link: String) {
            self.id = id
            self.link = link
            self.assignee = ""
            self.radar = ""
            self.resolution = ""
            self.status = ""
            self.title = ""
            self.updated = ""
        }
    }
}
