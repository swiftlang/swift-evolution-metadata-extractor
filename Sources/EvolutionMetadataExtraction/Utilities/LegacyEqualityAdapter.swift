
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import EvolutionMetadataModel

// These are temporary fixtures to aid in testing the migration from the legacy tool.
//
// The 'equality adaptor' takes known and acceptable differences between what the legacy and new tools output.
//
// This file can be removed after the migration.

extension Proposal {
    func isEqualToLegacyProposal(_ legacyProposal: Proposal) -> Bool {
        return (legacyProposal.id == self.id &&
           legacyProposal.sha == self.sha &&
           legacyProposal.link == self.link &&
           legacyProposal.title.trimmingCharacters(in: .whitespacesAndNewlines) == self.title &&
           legacyProposal.status == self.status &&
           legacyProposal.reviewManager == self.reviewManager &&
           legacyProposal.authors == self.authors &&
           legacyProposal.trackingBugs == self.trackingBugs &&
           legacyProposal.errors == self.errors &&
           LegacyEqualityAdapter.implementationsAreEqual(propID: id, old: legacyProposal.implementation, new: self.implementation) &&
           LegacyEqualityAdapter.summariesAreEqual(propID: legacyProposal.id, old: legacyProposal.summary, new: self.summary))
    }
}

struct LegacyEqualityAdapter {
    
    // These represent implementation links that are parsed by the new tool, but not the legacy tool.
    // This data structure is for use during the transition to the new tool as an 'adaptor'.
    // Adding these to the existing generated json file will make the two equal
    static let implementationEqualityAdapter: [String : [Proposal.Implementation]] = [
        "SE-0356" : [
            Proposal.Implementation(account: "apple", id: "61", repository: "swift-docc", type: "pull"), Proposal.Implementation(account: "apple", id: "3694", repository: "swift-package-manager", type: "pull"), Proposal.Implementation(account: "apple", id: "3732", repository: "swift-package-manager", type: "pull"), Proposal.Implementation(account: "apple", id: "10", repository: "swift-docc-symbolkit", type: "pull"), Proposal.Implementation(account: "apple", id: "15", repository: "swift-docc-symbolkit", type: "pull"), Proposal.Implementation(account: "apple", id: "7", repository: "swift-docc-plugin", type: "pull")
        ],
        "SE-0264" : [
            Proposal.Implementation(account: "apple", id: "1089", repository: "swift-evolution", type: "pull"), Proposal.Implementation(account: "apple", id: "1090", repository: "swift-evolution", type: "pull"), Proposal.Implementation(account: "apple", id: "1091", repository: "swift-evolution", type: "pull")
        ],
        "SE-0225" : [
            Proposal.Implementation(account: "apple", id: "18689", repository: "swift", type: "pull")
        ]
    ]
    
    static let summaryEqualityAdapter: [String: [(String, String)]] = [
        "SE-0005" : [
            ("\"APIDesignGuidelines\"", ""),
            ("\"CodingGuidelinesforCocoa\"", ""),
        ],
        "SE-0006" : [
            ("\"APIDesignGuidelines\"", ""),
        ],
        "SE-0033" : [
            ("\\!", "!"),
        ],
        "SE-0039" : [
            ("\\#", "#"),
        ],
        "SE-0224" : [
            ("\\<", "<"),
        ],
        "SE-0229" : [
            ("\\<", "<"),
            ("\\>", ">"),
        ],
        "SE-0225" : [
            ("\\(", "("),
            ("\\)", ")"),
        ],
        "SE-0307" : [
            ("\\<", "<"),
            ("\\>", ">"),
        ],
        "SE-0321" : [
            ("\"PackageRegistryService\"", ""),
        ],
    ]
    
    static func summariesAreEqual(propID: String, old: String, new: String) -> Bool {
        if old == new {
            return true
        } else {
            let searchRegex = /[\s\n]+/
            let oldWithoutWhitespace = old.replacing(searchRegex, with:"")
            let newWithoutWhitespace = new.replacing(searchRegex, with:"")
            
            if oldWithoutWhitespace == newWithoutWhitespace {
                return true
            } else if let valuesForProposal = LegacyEqualityAdapter.summaryEqualityAdapter[propID] {
                var oldWithLinkTitlesRemoved = oldWithoutWhitespace
                for (linkTitle, replacement) in valuesForProposal {
                    oldWithLinkTitlesRemoved = oldWithLinkTitlesRemoved.replacingOccurrences(of: linkTitle, with: replacement)
                }
                //            print(oldWithLinkTitlesRemoved)
                if oldWithLinkTitlesRemoved == newWithoutWhitespace {
                    return true
                }
            }
        }
        
        return false
        
    }
    
    static func implementationsAreEqual(propID: String, old: [Proposal.Implementation]?, new: [Proposal.Implementation]?) -> Bool {
        if old == new {
            return true
        } else if let asdf = LegacyEqualityAdapter.implementationEqualityAdapter[propID] {
            return asdf == new
        } else {
            return false
        }
    }
    
}
