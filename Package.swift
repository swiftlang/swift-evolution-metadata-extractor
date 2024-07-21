// swift-tools-version: 5.9

// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import PackageDescription

// Settings to use for all targets
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ImportObjcForwardDeclarations"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
]

let package = Package(
    name: "swift-evolution-metadata-extractor",
    platforms: [ .macOS(.v14) ],
    products: [
        .library(name: "EvolutionMetadataModel", targets: ["EvolutionMetadataModel"]),
        .executable(name: "swift-evolution-metadata-extractor", targets: ["swift-evolution-metadata-extractor"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "swift-evolution-metadata-extractor",
            dependencies: [
                "EvolutionMetadataExtraction",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "EvolutionMetadataExtraction",
                        dependencies: [
                "EvolutionMetadataModel",
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "EvolutionMetadataModel",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ExtractionTests",
            dependencies: [
                "EvolutionMetadataExtraction"
            ],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
