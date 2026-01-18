#!/bin/bash

set -euo pipefail

# update-all-proposals-snapshot
#
# The AllProposals snapshot should be updated periodically so that it contains
# a recent snapshot of proposals in the swift-evolution repository.
#
# This script generates an updated AllProposals snapshot.
#
# The previous snapshot is moved to a 'ReplacedFiles' directory.
#
# The intended workflow is to inspect the changes of the newly generated snapshot,
# ensure tests pass, commit the changes, and delete the ReplacedFiles directory and its contents.
#

script_dir="$(cd "$(dirname "$0")" && pwd)"
"$script_dir/update-test-files.sh" AllProposals
