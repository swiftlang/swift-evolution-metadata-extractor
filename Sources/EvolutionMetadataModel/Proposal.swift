
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

/**
    JSON model
```
    {
        "id": String, // SE-NNNN, e.g. "SE-0147"
        "title": String,
        "summary": String,
        "link": String,
        "sha": String, // SHA of the proposal's Markdown file's latest update
        "authors": [ // [Proposal.Person]
             {
                 "name": String,
                 "link": String // warns on absence
             }
         ],
        "reviewManager": { // Proposal.Person // warns
            "name": String,
            "link": String,
        },
        "status": {
            "state": String, // Proposal.Status case name, e.g. ".implemented"
            "start": String?, // ISO 8601 date string, key only present for status states with dates
            "end": String?, // ISO 8601 date string, same as above
            "version": String?, // swift version number, e.g. "3.0.2"
        },
        "trackingBugs": [ // [Proposal.TrackingBug]?
            {
                "assignee": String,
                "id": String,
                "link": String,
                "radar": String,
                "resolution": String,
                "status": String,
                "title": String,
                "updated": String,
            }
        ],
        "implementation": [ // [Proposal.Implementation]?
            {
                "type": String, // "commit" | "pull"
                "account": String,
                "repository": String,
                "id": String
            }
        ],

        "warnings": [{ // [Proposal.Issue]?, key missing if array is empty
            "kind": "warning", // differentiates this from an error
            "message": String, // human-readable description of what's wrong
            "stage": String // e.g. "parse"
        }],
        "errors": [{ // [Proposal.Issue]?, key missing if array is empty
            "kind": "error", // differentiates this from a warning
            "message": String, // human-readable description of what's wrong
            "stage": String // e.g. "parse"
        }]
    }
```
Attributes are `var` variables and not `let` constants to make it easier to build up a result when extracting the metadata. When using this to decode JSON, creating a let variable will make the results immutable.
 
*/

public struct Proposal: Equatable, Sendable, Codable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var link: String
    public var sha: String
    public var authors: [Person]
    public var reviewManager: Person
    public var status: Status
    public var trackingBugs: [TrackingBug]?
    public var implementation: [Implementation]?
    public var warnings: [Issue]?
    public var errors: [Issue]?
    
    public init(id: String = "", title: String = "", summary: String = "", link: String = "", sha: String = "", authors: [Person] = [], reviewManager: Person = Person(), status: Status = .error, trackingBugs: [TrackingBug]? = nil, implementation: [Implementation]? = nil, warnings: [Issue]? = nil, errors: [Issue]? = nil)
    {
        self.id = id
        self.title = title
        self.summary = summary
        self.link = link
        self.sha = sha
        self.authors = authors
        self.reviewManager = reviewManager
        self.status = status
        self.trackingBugs = trackingBugs
        self.implementation = implementation
        self.warnings = warnings
        self.errors = errors
    }
}
