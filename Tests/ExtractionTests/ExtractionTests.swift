
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import XCTest
import Foundation

@testable import EvolutionMetadataModel
@testable import EvolutionMetadataExtraction

final class ExtractionTests: XCTestCase {
    
    func urlForSnapshot(named snapshotName: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: snapshotName, withExtension: "evosnapshot", subdirectory: "Resources"), "Unable to find snapshot \(snapshotName).evosnapshot in test bundle resources.")
    }
    
    func testAllProposals() async throws {
        
        let snapshotURL = try urlForSnapshot(named: "AllProposals")
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
        let expectedResults = try XCTUnwrap(extractionJob.expectedResults, "Snapshot at '\(snapshotURL.absoluteString)' does not contain expected results.")
        let expectedResultsByProposalID = expectedResults.reduce(into: [:]) { $0[$1.id] = $1 }
        
        let extractedEvolutionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
        
        for newProposal in extractedEvolutionMetadata.proposals {
            let id = newProposal.id
            guard !id.isEmpty  else {
                continue
            }
            
            guard let sourceProposal = expectedResultsByProposalID[id] else {
                XCTFail("Unable to find id \(id) in expected results.")
                continue
            }
            
            XCTAssertEqual(newProposal, sourceProposal)
        }
    }
    
    func testWarningsAndErrors() async throws {
        
        let snapshotURL = try urlForSnapshot(named: "Malformed")
        let extractionJob = try await ExtractionJob.makeExtractionJob(from: .snapshot(snapshotURL), output: .none, ignorePreviousResults: true)
        let expectedResults = try XCTUnwrap(extractionJob.expectedResults, "No expected results found in bundle '\(snapshotURL.absoluteString)'")
        
        // VALIDATION ENHANCEMENT: Tools like Xcode like to add a newline character to empty files
        // Possibly instead of using 0007-empty-file.md to test, test separately?
        // Or test that the file hasn't been corrupted. (Can you even check it into github?)

        let extractionMetadata = try await EvolutionMetadataExtractor.extractEvolutionMetadata(for: extractionJob)
        
        // This test zips the extraction results with the expected results
        // If the two arrays don't have the same count, the test data itself has an error
        XCTAssertEqual(extractionMetadata.proposals.count, expectedResults.count)
        
        for (actualResult, expectedResult) in zip(extractionMetadata.proposals, expectedResults) {
            XCTAssertEqual(actualResult, expectedResult)
        }
    }
    
    func testGoodDates() throws {
        guard let reviewDatesURL = Bundle.module.url(forResource: "review-dates-good", withExtension: "txt", subdirectory: "Resources") else {
            print("Could not find review-dates.txt")
            return
        }
        
        guard let reviewDatesData = try? Data(contentsOf: reviewDatesURL) else {
            print("Could not read review-dates.txt")
            return
        }
        
        guard let reviewDatesContents = String(data: reviewDatesData, encoding: .utf8) else {
            print("Could not make string from contents of review-dates.txt")
            return
        }
        
        let statusStrings = reviewDatesContents.split(separator: "\n")
        
        //        var errorsFound = 0
        for statusString in statusStrings {
            // NOTE: This is something that should be validated!
            // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
            let match = try XCTUnwrap(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )
            
            let statusDetail = String(match.1)
            
            XCTAssertNotNil(StatusExtractor.datesForString(statusDetail, processingDate: Date.now), "Unable to parse '\(statusDetail)'")
        }
    }
    
    func testBadDates() throws {
        guard let reviewDatesURL = Bundle.module.url(forResource: "review-dates-bad", withExtension: "txt", subdirectory: "Resources") else {
            print("Could not find review-dates-bad.txt")
            return
        }
        
        guard let reviewDatesData = try? Data(contentsOf: reviewDatesURL) else {
            print("Could not read review-dates-bad.txt")
            return
        }
        
        guard let reviewDatesContents = String(data: reviewDatesData, encoding: .utf8) else {
            print("Could not make string from contents of review-dates.txt")
            return
        }
        
        let statusStrings = reviewDatesContents.split(separator: "\n")
        
        //        var errorsFound = 0
        for statusString in statusStrings {
            // NOTE: This is something that should be validated!
            // It seems a common mistake to leave out closing parenthesis or put strong marker inside closing paren
            let match = try XCTUnwrap(statusString.firstMatch(of: /\((.*)\)/), "Every review item in status strings should have parenthesis with contents. \(statusString) DOES NOT MATCH PATTERN" )
            
            let statusDetail = String(match.1)
            
            XCTAssertNil(StatusExtractor.datesForString(statusDetail, processingDate: Date.now), "Unexpectedly able to parse '\(statusDetail)'")
        }
    }
}

