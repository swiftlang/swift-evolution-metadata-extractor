# swift-evolution-metadata-extractor
JSON metadata generator for Swift Evolution dashboard.

## Overview
The `swift-evolution-metadata-extractor` tool reads the main branch of the `swift-evolution` repository, extracts proposal metadata and generates a JSON file used as the data source for the [Swift Evolution Dashboard](https://swift-org/swift-evolution).

In addition to the extraction tool, this package vends the `EvolutionMetadataModel` library which provides types for encoding and decoding evolution metadata JSON files. This library is intended for use by clients of the metadata file that drives the evolution dashboard. 

## Basic usage

`swift-evolution-metadata-extractor`

Running the command with no arguments will do the following:
1. Fetch listing of current proposals from `swift-evolution` repository
2. Fetch previous metadata results from `swift.org`
3. Fetch and extract metadata from proposals with changes
4. Write the extracted metadata to a `proposal.json` file in the same directory as the command

The default behavior can be configured in various ways.

### Output path

Use the `--output-path` option (`-o`) to specify a different location or filename.

Uses default filename and writes `proposals.json` to `~/Desktop`:  
`swift-evolution-metadata-extractor --output-path ~/Desktop`

Writes `my-metadata.json` at the specified location:  
`swift-evolution-metadata-extractor -o ~/Desktop/my-metadata.json`

If the specified path does not exist, the tool will attempt to create the necessary directories.

### Force extract

By default, the SHA values of previously extracted proposals are used to avoid processing proposals with no changes.

Use the `--force-extract` option to force all or specified proposals to be fetched and processed.

To force all proposals to be processed ignoring previous results:  
`swift-evolution-metadata-extractor --force-extract all`

To force a specific proposal to be processed:  
`swift-evolution-metadata-extractor --force-extract SE-0287`

Use the `--force-extract` option multiple times for multiple proposals:  
`swift-evolution-metadata-extractor --force-extract SE-0287 --force-extract SE-0123`

### Snapshot path

Use the `--snapshot-path` option to specify a local `evosnapshot` directory during development.

See _Snapshots for development and testing_ for more information about snapshots.

### Verbose output

Use the `--verbose` option (`-v`) for verbose output as the tool runs.

## EvolutionMetadataModel library
The package vends the `EvolutionMetadataModel` library. The library defines `Codable` types that are suitable for decoding the generated evolution metadata file.

## Snapshots for development and testing
The tool is able to record snapshots of input files and expected results for use in development and testing.

Ad-hoc snapshots can also be manually created to create content for specifc tests such as verifying that validation errors are correctly detected in malformed proposals.

Snapshots are directories with the file extension `evosnapshot` but are not formally declared as bundles on macOS.

`swift-evolution-metadata-extractor snapshot`

The expected contents of an evosnapshot is as follows:

```
proposals/XXXX-proposal-files.md // Directory of proposal markdown files
expected-results.json            // Expected results from the source data. If present, will compare at end of run.
previous-results.json            // Previous results. If present, will be used in processing unless forced extraction is specified.
proposal-listing.json            // Results of GitHub query of proposals directory. Contains proposal SHA values.
source-info.json                 // Results of GitHub query about the branch or PR, includes name and an identifier.
```        

### Ad-hoc snapshots
For testing, a variety of situations representing malformed proposals or rarely encountered states can be represented in manually constructed snapshots.

For example, the `Malformed.evosnapshot` is used to test content validation warnings and errors.

These ad hoc snapshots often include only a `proposals` directory and a `expected-results.json` file.

Generally there is no `previous-results.json` file present in a snapshot, but could be present in snapshots that are used to test using previous results or forced extraction.
