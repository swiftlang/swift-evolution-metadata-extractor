This snapshot is used in tests to simulate running the extractor tool when the previous results are identical to the current state of the swift-evolution repository.

The `commit` field of the `previous-results.json` is the same as the commit SHA value of the `source-info.json`.

The tests that use this snapshot check that previous results are used, that force extracting all or some proposals works correctly, and that the generated metadata is the same in all cases, since they all use data from the same commit.