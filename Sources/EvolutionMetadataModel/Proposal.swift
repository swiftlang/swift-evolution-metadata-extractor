
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

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
         "reviewManagers":  [ // [Proposal.Person]
              {
                  "name": String,
                  "link": String // warns on absence
              }
         ],
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
            "code": Int, // unique identifier across warning and errors
            "message": String, // human-readable description of what's wrong
            "suggestion": String // suggestion of how to correct the issue
        }],
        "errors": [{ // [Proposal.Issue]?, key missing if array is empty
            "kind": "error", // differentiates this from a warning
            "code": Int, // unique identifier across warning and errors
            "message": String, // human-readable description of what's wrong
            "suggestion": String // suggestion of how to correct the issue
        }]
    }
```
Attributes are `var` variables and not `let` constants to make it easier to build up a result when extracting the metadata. When using this to decode JSON, creating a let variable will make the results immutable.
 
*/

public struct Proposal: Equatable, Sendable, Codable, Identifiable {

    /// Proposal ID in the format _SE-NNNN_. For example: "SE-0147"
    public var id: String
    
    /// Proposal title as a Markdown string
    ///
    /// The contents depend on the proposal itself, but typically only backtick characters appear in titles to indicate code voice.
    public var title: String
    
    /// Proposal summary as a Markdown string
    public var summary: String
    
    /// Filename and relative link to the proposal in the repository
    public var link: String
    
    /// SHA1 hash of the proposal version used as the metadata source
    public var sha: String
    
    /// Array of proposal authors
    public var authors: [Person]

    /// Array of proposal review managers
    public var reviewManagers: [Person]

    /// Proposal status
    public var status: Status
    
    /// Optional upcoming feature flag
    public var upcomingFeatureFlag: UpcomingFeatureFlag?
    
    /// Optional array of previous proposal IDs in the format _SE-NNNN_
    public var previousProposalIDs: [String]?
    
    /// Optional array of tracking bugs
    public var trackingBugs: [TrackingBug]?
    
    /// Optional array of implementation links
    public var implementation: [Implementation]?
    
    /// Array of discussions about the proposal. May be an empty array.
    public var discussions: [Discussion]
    
    /// Optional array of warnings
    ///
    /// Present only if validation warnings were found when extracting metadata from this proposal.
    public var warnings: [Issue]?
    
    /// Optional array of errors
    ///
    /// Present only if validation errors were found when extracting metadata from this proposal.
    public var errors: [Issue]?
    
    public init(id: String = "", title: String = "", summary: String = "", link: String = "", sha: String = "", authors: [Person] = [], reviewManagers: [Person] = [], status: Status = .statusExtractionNotAttempted, trackingBugs: [TrackingBug]? = nil, implementation: [Implementation]? = nil, discussions: [Discussion] = [], warnings: [Issue]? = nil, errors: [Issue]? = nil)
    {
        self.id = id
        self.title = title
        self.summary = summary
        self.link = link
        self.sha = sha
        self.authors = authors
        self.reviewManagers = reviewManagers
        self.status = status
        self.trackingBugs = trackingBugs
        self.implementation = implementation
        self.discussions = discussions
        self.warnings = warnings
        self.errors = errors
    }
}
