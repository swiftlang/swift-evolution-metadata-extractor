
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import EvolutionMetadataModel

struct PreviousResultsFetcher {
    
    static let previousResultsURL = URL(string: "https://download.swift.org/swift-evolution/v1/evolution.json")!
    
    static func fetchPreviousResults() async throws -> [Proposal] {
        let request = URLRequest(url: previousResultsURL, cachePolicy: .reloadIgnoringLocalCacheData)
        verbosePrint("Fetching with URLRequest:\n\(request.verboseDescription)")
        do {
            let (data, _) = try await URLSession.customized.data(for: request)
            
            do {
                let decoder = JSONDecoder()
                let evolutionMetadata = try decoder.decode(EvolutionMetadata.self, from: data)
                return evolutionMetadata.proposals
            } catch {
                print("Unable to decode \(EvolutionMetadata.self) from:")
                print(String(decoding: data, as: UTF8.self))
                throw error
            }
        } catch {
            print(error)
            throw error
        }
    }
}

// MARK: - GitHub Access

struct GitHubBranch: Codable {
    let name: String
    let commit: Commit
    struct Commit: Codable {
        let sha: String
    }
}

struct GitHubContentItem: Codable {
    var name: String
    var path: String
    var sha: String
    var size: Int
    var url: String
    var html_url: String
    var git_url: String
    var download_url: String
    var type: String
    var _links: LinkContainer
    
    struct LinkContainer: Codable {
        var `self`: String
        var git: String
        var html: String
    }
    
    func proposalSpec(sortIndex: Int) ->  ProposalSpec {
        ProposalSpec(url: URL(string: download_url)!, sha: sha, sortIndex: sortIndex)
    }
}

struct GitHubPullFileItem: Codable {
    var sha: String
    var filename: String
    var status: String
    var additions: Int
    var deletions: Int
    var changes: Int
    var blob_url: String
    var raw_url: String
    var contents_url: String
    var patch: String
    
    func proposalSpec(sortIndex: Int) ->  ProposalSpec {
        ProposalSpec(url: URL(string: raw_url)!, sha: sha, sortIndex: sortIndex)
    }

}

struct GitHubFetcher {
    
    struct Endpoint {
        static let githubMainBranchEndpoint = URL(string: "https://api.github.com/repos/apple/swift-evolution/branches/main")!
        static let githubIssuesEndpoint = URL(string: "https://api.github.com/repos/apple/swift/issues?since=2023-08-01T01:00:00Z&state=all")!
        static let githubProposalsEndpoint = URL(string: "https://api.github.com/repos/apple/swift-evolution/contents/proposals")!
        static func githubPullEndpoint(for request: String) -> URL {
            URL(string: "https://api.github.com/repos/apple/swift-evolution/pulls/\(request)/files")!
        }
    }
    
    static let gitHubTokenHeaderValue: String? = {
        if let githubToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            "Bearer \(githubToken)"
        } else {
            nil
        }
    }()
    
    // Note that fetching proposal contents does not use GitHub API endponts
    static func fetchProposalContents(from url: URL) async throws -> String {
        let (data, _) =  try await URLSession.customized.data(from: url)
        return String(decoding: data, as: UTF8.self)
    }
        
    static func fetchMainBranch() async throws -> GitHubBranch {
        // Always reload since a new commit may have occurred.
        // Caching for other calls is fine since the branch commit SHA is included in the requested URL
        let branchInfo = try await getGitHubAPIValue(for: Endpoint.githubMainBranchEndpoint, type: GitHubBranch.self, cachePolicy: .reloadIgnoringLocalCacheData)
        return branchInfo
    }
    
    // For creating snapshots we need access to the 'raw' GitHub content items
    static func fetchProposalContentItems(for reference: String? = nil) async throws -> [GitHubContentItem] {
        var endpoint = Endpoint.githubProposalsEndpoint
        if let reference {
            endpoint.append(queryItems: [URLQueryItem(name: "ref", value: reference)])
        }
        return try await getGitHubAPIValue(for: endpoint, type: [GitHubContentItem].self)
    }

    static func fetchPullRequestProposalList(for pullNumber: String) async throws -> [GitHubPullFileItem] {
        let endpointURL = Endpoint.githubPullEndpoint(for: pullNumber)
        let contents = try await getGitHubAPIValue(for: endpointURL, type: [GitHubPullFileItem].self)
        return contents
            .filter { $0.filename.hasPrefix("proposals/") }
    }
    
    static func getGitHubAPIValue<T: Decodable>(for endpoint: URL, type: T.Type, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> T {
        
        var request = URLRequest(url: endpoint, cachePolicy: cachePolicy)
        request.setValue(gitHubTokenHeaderValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        verbosePrint("Fetching with URLRequest:\n\(request.verboseDescription)")
        
        do {
            let (data, response) = try await URLSession.customized.data(for: request)
            
            if verboseEnabled, let httpResponse = response as? HTTPURLResponse {
                print("Response from", endpoint)
                let fields = ["x-ratelimit-limit", "x-ratelimit-remaining", "x-ratelimit-used", "x-ratelimit-reset"]
                for field in fields {
                    if field == "x-ratelimit-reset" {
                        if let rawValue = httpResponse.value(forHTTPHeaderField: field) {
                            let date = Date(timeIntervalSince1970: TimeInterval(Int(rawValue) ?? 0))
                            print("\(field):", DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .long), "(raw value: \(rawValue))")
                        } else {
                            print("\(field):", "no value")
                        }
                    } else {
                        print("\(field):", httpResponse.value(forHTTPHeaderField: field) ?? "no value")
                    }
                }
                print()
            }
            
            do {
                let decoder = JSONDecoder()
                let items = try decoder.decode(T.self, from: data)
                return items
            } catch {
                print("Unable to decode \(T.self) from:")
                print(String(decoding: data, as: UTF8.self))
                throw error
            }
        } catch {
            print(error)
            throw error
        }
    }
}
