# CHANGELOG

<!--
Add new items at the end of the relevant section under **Unreleased**.
-->

## [Unreleased]

### Additions

- Add `validate` subcommand to generate validate reports

### Changes

- Support extraction of new "Summary of changes" section ([#79])

### Fixes

*No fixes*

---

## [1.0.0] - 2026-01-20

### Additions

- Add support for Linux ([#56])
- Adopt Swift 6 language mode
- Add Hashable conformance to model types
- Enable documentation generation in Swift Package Index ([#38])
- Add tests for snapshot generation and previous result reuse
- Add output to standard out for `extract` command ([#58])
- Add proposal paths argument to `snapshot` and `extract` commands ([#63], [#70])
- Add utility scripts to update test files ([#74])

### Changes

- Migrate tests to Swift Testing ([#51])
- Update test data to lastest set of proposals and current metadata schema ([#72])
- Filter out files that are not Markdown
- Improve performance of pretty-printed JSON generation
- Use full metadata struct as previous results
- Refactor snapshot details and extraction job metadata into separate types
- Stop writing legacy `proposals.json` placeholder file
- Ensure generated metadata always uses current tool version ([#66])
- Always perform full extraction if schema or tool version changes ([#67])

### Fixes

- Fix crash due to addition of subdirectory of `proposals/` in `swift-evolution` repository ([#48])
- Add workaround for swift-markdown package change preventing compilation
- Fix typo in README ([#44])

---

## [0.1.0] - 2024-07-22

- `swift-evolution-metadata-extractor` initial release.

---

This changelog's format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!-- Link references for releases -->

[Unreleased]: https://github.com/swiftlang/swift-evolution-metadata-extractor/compare/1.0.0...HEAD
[1.0.0]: https://github.com/swiftlang/swift-evolution-metadata-extractor/releases/tag/0.1.0...1.0.0
[0.1.0]: https://github.com/swiftlang/swift-evolution-metadata-extractor/releases/tag/0.1.0

<!-- Link references for pull requests -->

[#38]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/38
[#44]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/44
[#48]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/48
[#51]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/51
[#56]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/56
[#58]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/58
[#63]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/63
[#66]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/66
[#67]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/67
[#70]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/70
[#72]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/72
[#74]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/74
[#79]: https://github.com/swiftlang/swift-evolution-metadata-extractor/pull/79
