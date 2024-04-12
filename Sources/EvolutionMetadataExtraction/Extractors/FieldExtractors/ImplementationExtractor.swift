
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import Markdown
import EvolutionMetadataModel

struct ImplementationExtractor: MarkupWalker, ValueExtractor {

    private var warnings: [Proposal.Issue] = []
    private var errors: [Proposal.Issue] = []

    private var implementaton: [Proposal.Implementation]? {
        _implementaton.isEmpty ? nil : _implementaton
    }
    private var _implementaton: [Proposal.Implementation] = []
    
    mutating func extractValue(from headerFieldsByLabel: [String : ListItem]) -> ExtractionResult<[Proposal.Implementation]> {
        if let (_ , headerField) = headerFieldsByLabel[["Implementation", "Implementations"]] {
            visit(headerField)
        }
        // Implementation field is optional. Take no action / add no warning if it is not found
        
        return ExtractionResult(value: implementaton, warnings: warnings, errors: errors)
    }

    
    mutating func visitLink(_ link: Link) -> () {
        guard let values = LinkInfo(link: link) else {
            // VALIDATION ENHANCEMENT: Add warning or error malformed / misformatted status
            return
        }
        
        guard let url = URL(string: values.destination) else {
            // VALIDATION ENHANCEMENT: Add warning or error malformed / misformatted status
            return
        }

        // We need 5 components: ["/", orgname, reponame, "pull" | "commit", id]
        // Values that do not fit the data scheme
//        SE-0389 'https://github.com/DougGregor/swift-macro-examples'
//        SE-0382 'https://github.com/DougGregor/swift-macro-examples'
//        SE-0363 'https://github.com/apple/swift-experimental-string-processing/'
//        SE-0357 'https://github.com/apple/swift-experimental-string-processing/'
//        SE-0356 'https://swift.org/download/#snapshots'
//        SE-0356 'https://github.com/apple/swift-docc-plugin'
//        SE-0344 'https://swift.org/download/#snapshots'
//        SE-0336 'https://swift.org/download/#snapshots'
//        SE-0313 'https://swift.org/download/#snapshots'
//        SE-0306 'https://swift.org/download/#snapshots'
//        SE-0305 'https://swift.org/download/#snapshots'
//        SE-0304 'https://swift.org/download/#snapshots'
//        SE-0297 'https://swift.org/download/#snapshots'
//        SE-0282 'https://github.com/apple/swift-atomics'
        if url.pathComponents.count < 5 {
//            print(id, "'\(url)'")
            return
        }

        let account = url.pathComponents[1]
        let repository = url.pathComponents[2]
        let type = url.pathComponents[3]
        let implID = url.pathComponents[4]
        
        // Only record values that are pulls or commits
        guard type == "pull" || type == "commit" else {
            return
        }
        
        // VALIDATION ENHANCEMENT: The legacy tool lowercases the tested value. This is probably not necessary.
        guard account == "apple" else {
            warnings.append(ValidationIssue.invalidImplementationLink)
            return
        }
        
        let newValue = Proposal.Implementation(account: account, repository: repository, type: type, id: implID)
        _implementaton.append(newValue)
    }
}
