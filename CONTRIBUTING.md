# Contributing

By submitting a pull request, you represent that you have the right to license
your contribution to Apple and the community, and agree by submitting the patch
that your contributions are licensed under the [Swift
license](https://swift.org/LICENSE.txt).

Before submitting the pull request, please make sure you have tested your
changes and that they follow the Swift project [guidelines for contributing
code](https://swift.org/contributing/#contributing-code).

## Guidelines

- **The Swift Evolution proposal markdown files serve as the source of truth for the extracted metadata.**

   It is not a goal for this tool to use the extracted metadata as a starting point for fetching and extracting additional information. Clients of the published metadata are welcome to create tools that do so.

- **Please propose schema or command line interface changes as an issue first, before submitting a pull request.**

  Schema changes and tool interface changes need to be discussed and considered. To avoid the effort of developing and creating a pull request that may not be accepted, please submit an issue that proposes/pitches the change.

- **Pull requests for other changes, such as bug fixes, that do not change the schema or command line interface are welcome.**

## Development Workflow

A focus of the development workflow is the ability to quickly detect unintended changes to the extracted metadata and generated JSON. Both the package tests and the tool itself use snapshots to achieve this.

### Getting Started
After cloning the project, use `swift test` or the Xcode test action to verify that all tests pass.

A useful set of options to use when getting started:  
`--snapshot-path default -o ~/Desktop --verbose`

This will:
- Extract data from a default snapshot in the test bundle containing current proposal files 
- Write output files to `~/Desktop`
- Log verbose output

The project [README](README.md) describes the full list of command line options and environment variables you can use with the tool.

### Using snapshots
Snapshots provide a self-contained collection of source files and expected results to provide repeatable results in testing and development without requiring network access.

Specifying a snapshot path when running the tool has these benefits during development:

- Faster testing of extraction code by using local proposal files
- Automatic checking against expected results to quickly catch unexpected output changes
- Repeatable set of inputs every time the tool is run

### Using network source
By default, the tool uses the network. Also by default, the previous extraction results are used so unchanged proposals are not processed.

When developing using the network, use `--force-extract all` so that all proposals are fetched and processed.

#### GitHub API Token
The tool uses the GitHub API which rate-limited. The hourly rate is high enough to get started developing without needing a GitHub token. For a higher limit, you can use a GitHub personal access token ([Details here](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api?apiVersion=2022-11-28)). Pass the token to the tool using environment variable `GITHUB_TOKEN`.


## Versioning

The package uses semantic versioning with the public metadata schema and public command line interface considered to be the interface of the package.

The schema and tool versions are included in the generated metadata and incremented separately. This provides schema and tool version information to clients of the metadata file regardless of client language or environment.

### Schema Version
The schema version is incremented as follows:

- Major version: Breaking changes such as removing or renaming properties or changing field type or structure

- Minor version: Non-breaking changes such as adding properties as well as non-breaking changes to the public EvolutionMetadataModel API.
    
- Patch version: A significant change in the content returned could be noted with a patch version. This is unlikely to be used often.

When a major or minor change is made to the schema, the baseline model types in the BaselineModel directory of the test target should also be updated for the new baseline.

### Tool Version
The tool version is incremented as follows:

- Major version: Breaking changes in the command line interface that would break scripting clients.

- Minor version: Non-breaking changes in the command line interface such as adding subcommand or options.
    
- Patch version: Things such as bug fixes or changes in how the metadata is extracted

### Package Version
When the schema or tool version increments, the package version is incremented in the same way (major/minor/patch).

The package version may also be incremented for bug fixes or internal improvements that do not affect the public interface of the schema or the tool.
