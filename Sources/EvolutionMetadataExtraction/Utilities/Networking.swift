
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
    
    static let previousResultsURL = URL(string: "https://download.swift.org/swift-evolution/proposals.json")!
    
    static func fetchPreviousResults() async throws -> [Proposal] {
        let request = URLRequest(url: previousResultsURL, cachePolicy: .reloadIgnoringLocalCacheData)
        verbosePrint("Fetching with URLRequest:\n\(request.requestDump)")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            //        let (data, _) = try await URLSession.shared.data(from: URL(string: previousResultsURL)!)
            let decoder = JSONDecoder()
            let items = try decoder.decode([Proposal].self, from: data)
            return items
        } catch {
            print(error)
            throw error
        }
    }
}

// MARK: -

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
    
    var proposalSpec: ProposalSpec {
        ProposalSpec(url: URL(string: download_url)!, sha: sha)
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
    
    // Note that fetching proposal contents does not use GitHub API endponts
    static func fetchProposalContents(from url: URL) async throws -> String {
        let (data, _) =  try await URLSession.shared.data(from: url)
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

    static func fetchPullRequestProposalList(for pullNumber: String) async throws -> [ProposalSpec] {
        let endpointURL = Endpoint.githubPullEndpoint(for: pullNumber)
        let contents = try await getGitHubAPIValue(for: endpointURL, type: [GitHubPullFileItem].self)
        return contents
            .filter { $0.filename.hasPrefix("proposals/") }
            .map { ProposalSpec(url: URL(string: $0.raw_url)!, sha: $0.sha) }
    }
    
    static func getGitHubAPIValue<T: Decodable>(for endpoint: URL, type: T.Type, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> T {
        
        var request = URLRequest(url: endpoint, cachePolicy: cachePolicy)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        verbosePrint("Fetching with URLRequest:\n\(request.requestDump)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
            
            let decoder = JSONDecoder()
            let items = try decoder.decode(T.self, from: data)
            return items
            
        } catch {
            print(error)
            throw error
        }
    }
}

extension URLRequest {
    fileprivate var requestDump: String {
        var dump = ""
        if let method = httpMethod {
            dump += method + " "
        }
        if let url = url {
            dump += String(describing: url) + "\n"
        }
        dump += "Timeout: \(timeoutInterval)\n"
        
        let cachePolicyString =  switch(cachePolicy) {
            case .useProtocolCachePolicy: "useProtocolCachePolicy"
            case .reloadIgnoringLocalCacheData: "reloadIgnoringLocalCacheData"
            case .reloadIgnoringLocalAndRemoteCacheData: "reloadIgnoringLocalAndRemoteCacheData"
            case .returnCacheDataElseLoad: "returnCacheDataElseLoad"
            case .returnCacheDataDontLoad: "returnCacheDataDontLoad"
            case .reloadRevalidatingCacheData: "reloadRevalidatingCacheData"
            default: "unknown cache policy"
        }
        dump += "Cache Policy: \(cachePolicyString)"

        if let headers = allHTTPHeaderFields {
            if !headers.isEmpty {
                dump += "\n"
                dump += "Headers:\n"
            }
            let lastIndex = headers.count - 1
            for (index, (key, value)) in headers.enumerated() {
                dump += "\t\(key) : \(value)\(index == lastIndex ? "" : "\n")"
            }
        }
        return dump
    }
}

