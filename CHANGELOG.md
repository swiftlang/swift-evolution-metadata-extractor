# CHANGELOG

<!--
Add new items at the end of the relevant section under **Unreleased**.
-->

## [Unreleased]

### Additions

- Add support for Linux
- Adopt Swift 6 language mode
- Add Hashable conformance to model types
- Enable documentation generation in Swift Package Index
- Add tests for snapshot generation and previous result reuse
- Add output to standard out for `extract` command
- Add proposal paths argument to `snapshot` command

### Changes

- Migrate tests to Swift Testing
- Update test data to lastest set of proposals and current metadata schema
- Filter out files that are not Markdown
- Improve performance of pretty-printed JSON generation
- Use full metadata struct as previous results
- Refactor snapshot details and extraction job metadata into separate types
- Stop writing legacy `proposals.json` placeholder file

### Fixes

- Fix crash due to addition of subdirectory of `proposals/` in `swift-evolution` repository
- Add workaround for swift-markdown package change preventing compilation
- Fix typo in README

---

## [0.1.0] - 2024-07-22

- `swift-evolution-metadata-extractor` initial release.

---

This changelog's format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!-- Link references for releases -->

[Unreleased]: https://github.com/swiftlang/swift-evolution-metadata-extractor/compare/0.1.0...HEAD
[0.1.0]: https://github.com/swiftlang/swift-evolution-metadata-extractor/releases/tag/0.1.0
