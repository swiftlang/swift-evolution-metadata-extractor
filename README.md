# swift-evolution-metadata-extractor
JSON metadata generator for Swift Evolution dashboard.

## Overview
The `swift-evolution-metadata-extractor` tool reads the main branch of the `swift-evolution` repository, extracts proposal metadata and generates a JSON file used as the data source for the [Swift Evolution Dashboard](https://swift.org/swift-evolution).

In addition to the extraction tool, this package vends the `EvolutionMetadataModel` library which provides types for encoding and decoding evolution metadata JSON files. This library is intended for use by clients of the metadata file that drives the evolution dashboard. 

## Usage

`swift-evolution-metadata-extractor`

Running the command with no arguments will do the following:
1. Fetch listing of current proposals from `swift-evolution` repository
2. Fetch previous metadata results from `swift.org`
3. Fetch and extract metadata from proposals with changes
4. Write the extracted metadata to a `evolution.json` file in the same directory as the command

The default behavior can be configured in various ways.

### Output path

Use the `--output-path` option (`-o`) to specify a different output location or filename.

If the specified path does not exist, the tool will attempt to create the necessary directories.

- Use a path ending with no file extension to specify path and use default file name:  

  `swift-evolution-metadata-extractor --output-path ~/Desktop`  
  
  > Will write output to `~/Desktop/evolution.json`

- Use a path ending with a file extension to specify path and file name:

  `swift-evolution-metadata-extractor -o ~/Desktop/my-metadata.json`  
  
  > Will write output to `~/Desktop/my-metadata.json`

- Use the value 'none' to suppress output:  

  `swift-evolution-metadata-extractor --output-path none`


### Force extract

By default, the SHA values of previously extracted proposals are checked to avoid processing proposals with no changes.

Use the `--force-extract` option to force all or specified proposals to be fetched and processed.

- Use the value 'all' to force all proposals to be processed, ignoring previous results:  
  `swift-evolution-metadata-extractor --force-extract all`

- Use a proposal identifier to force a specific proposal to be processed:  
  `swift-evolution-metadata-extractor --force-extract SE-0287`

- Use the `--force-extract` option multiple times for multiple proposals:  
  `swift-evolution-metadata-extractor --force-extract SE-0287 --force-extract SE-0123`

If the current schema or tool version is different from the previous results, the previous results will be ignored and a full extraction will be performed.

### Snapshot path

Use the `--snapshot-path` option to specify a local `evosnapshot` directory as a data source during development.

- Use the value 'default' to specify a default snapshot of all evolution proposals:  
  `swift-evolution-metadata-extractor --snapshot-path default`
  
- Use the value 'malformed' to specify a test snapshot of malformed evolution proposals:  
  `swift-evolution-metadata-extractor --snapshot-path malformed`

See [Snapshots for Development and Testing](#snapshots-for-development-and-testing) for more information about snapshots.

### Verbose output

Use the `--verbose` option (`-v`) for verbose output as the tool runs.

### Proposal files argument

Use trailing `<proposal-files>` argument of paths to proposal files in the Markdown format with the extension `md`.

This argument is primarily used in utility scripts within the project itself.

The `--snapshot-path` and `<proposal-files>` argument are mutually exclusive.


### Environment variables
Use optional environment variables to provide proxy and authorization information.

**HTTP_PROXY | http_proxy**  
When present, HTTP networking requests will use the specified proxy.

**HTTPS_PROXY | https_proxy**  
When present, HTTPS networking requests will use the specified proxy.

**GITHUB_TOKEN**  
When present, the provided token will be included as an authorization header in GitHub API requests.

## EvolutionMetadataModel Library
The package vends the `EvolutionMetadataModel` library. The library defines `Codable`, `Equatable`, `Sendable` value types that are suitable for decoding the generated evolution metadata file.

## Validation Reports
The `validate` command will extract metadata and generate a validation report containing any validation errors or warnings found.  By default the report will be written to standard out.

To validate the proposal files in a pull request, use the `--pull-request` option with the pull request number.

  `swift-evolution-metadata-extractor validate --pull-request 2474`
  
  > Will write a validation report of the proposal files in pull request #2474.

If validation errors are found the tool will exit with an error code.

The validate command is intended to be run on pull requests to ensure malformed proposal files are not committed.

### Options
The validate subcommand also has options that work similar to extract command options:
- Use the `--pull-request` option to specify a different output location or filename.

- Use the `--output-path` option (`-o`) to specify a different output location or filename.

- Use the `--verbose` option (`-v`) for verbose output as the tool runs.

- Use the `--snapshot-path` option to specify a local `evosnapshot` directory as a data source.

- Use trailing `<proposal-files>` argument of paths to proposal files in the Markdown format with the extension `md`.

  Use the `<proposal-files>` argument to validate one or more local proposal files.

The `--pull-request`, `--snapshot-path` and `<proposal-files>` argument are mutually exclusive.

## Snapshots for Development and Testing
Use the `snapshot` subcommand to record snapshots.

`swift-evolution-metadata-extractor snapshot`

A snapshot is a directory of input files and expected results for use in development and testing.  Snapshot directories use the file extension `evosnapshot` but are not formally declared as bundles on macOS.

Ad hoc snapshots can also be manually constructed to create content for specific tests such as verifying that validation errors are correctly detected in malformed proposals.

### Options
The snapshot subcommand has options that work similar to extract command options:
- Use the `--output-path` option (`-o`) to specify a different output location or filename.

- Use the `--verbose` option (`-v`) for verbose output as the tool runs.

- Use the `--snapshot-path` option to specify a local `evosnapshot` directory as a data source.
  
  When the expected results change for an existing snapshot, use this option to create a new snapshot containing the existing snapshot input files and the most recent expected results. This would be useful, for example when adding validation cases that generate new or different errors and warnings for proposals in the `Malformed.evosnapshot` snapshot.

- Use trailing `<proposal-files>` argument of paths to proposal files in the Markdown format with the extension `md`.

  Use the `<proposal-files>` argument to create an ad-hoc snapshot that will contain a `proposals` directory containing the copy of the specified files and an `expected-results.json` file.

The `--snapshot-path` and `<proposal-files>` argument are mutually exclusive.

  
### Snapshot structure and contents
A snapshot is a directory with the extension `evosnapshot` containing files with well-known names.

As described in [Ad hoc snapshots](#ad-hoc-snapshots), a snapshot can contain a subset of files.

For example, the snapshot generated by the `snapshot` subcommand does not include a `previous-results.json` file.

- Directory of proposal markdown files:  
`proposals/XXXX-proposal-files.md`

- Expected results from the source data:  
`expected-results.json`

- Results of GitHub query of proposals directory. Contains proposal SHA values:  
`proposal-listing.json`

- Results of GitHub query about the branch or PR. Includes name and an identifier:  
`source-info.json`

- Previous results. If present, will be used in processing unless forced extraction is specified:  
`previous-results.json`

### Ad hoc snapshots
For testing, a variety of situations representing malformed proposals or rarely encountered states can be represented in manually constructed snapshots.

For example, the `Malformed.evosnapshot` in the `ExtractionTests` target is used to test content validation warnings and errors.

These ad hoc snapshots often include only a `proposals` directory and an `expected-results.json` file.

Generally there is no `previous-results.json` file present in a snapshot, but could be present in snapshots that are used to test using previous results or forced extraction.
