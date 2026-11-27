# SE-0565: Allow Deprecating Package Products

* Proposal: [SE-0565](0565-title-contains-proposal-id.md)
* Authors: [Sam Khouri](https://github.com/bkhouri)
* Review Manager: [Tim Condon](https://github.com/0xTim)
* Status: **Active review (November 11...November 25, 2026)**
* Implementation: [swiftlang/swift-package-manager#10437](https://github.com/swiftlang/swift-package-manager/pull/10437) [swiftlang/swift-package-manager#10438](https://github.com/swiftlang/swift-package-manager/pull/10438)
* Review: ([pitch](https://forums.swift.org/t/pitch-deprecating-package-products-in-the-package-manifest/88468)) ([review](https://forums.swift.org/t/se-0565-allow-deprecating-package-products/90664))

> **Note on version numbers.** References to Swift tools version `6.5` and `_PackageDescription` availability `6.5` throughout this proposal are illustrative placeholders. The actual version in which the API becomes available depends on when this proposal is accepted and when the implementation lands in a released Swift toolchain. The final version will be substituted before this document is merged and again at implementation time.

## Introduction

Package authors currently have no first-class way to signal that a product vended from a Swift package is on a path to removal. Swift Package Manager (SwiftPM) supports rich deprecation semantics for Swift source APIs through `@available(*, deprecated, ...)`, but a `Package.swift` manifest cannot express that same intent for a `.library`, `.executable`, or `.plugin` product.

This proposal introduces a way to mark products as deprecated directly in the `Package.swift` manifest. Package authors describe the deprecation with a single factory, `.unsupported(message:replacement:)`, where the optional `replacement:` locator points at another product (in the same package or in a different package) that consumers should adopt instead. When a consumer package depends on an unsupported product, SwiftPM emits a warning at build time that surfaces the deprecation message and any replacement information declared by the producing package. A companion `swift package report` command lists every unsupported product in a package graph on demand, with an exit status that lets CI treat findings as failures.
