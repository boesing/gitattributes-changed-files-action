# Check Export-Ignore Changes

A composite GitHub Action that determines whether the changes between two commits touch any
path that is **not** marked `export-ignore` in `.gitattributes`. It has zero runtime
dependencies beyond `git`, which is already present on every GitHub-hosted runner.

## Usage

```yaml
name: Check export-ignore changes

on:
  push:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - id: check
        uses: boesing/gitattributes-changed-files-action@v1

      - name: React to the result
        if: steps.check.outputs.files_changed == 'true'
        run: echo "A file outside export-ignore paths changed."
```

The consuming workflow must check out the repository with enough history to contain both
compared commits (`fetch-depth: 0`, or at least enough to reach `base-sha`) before calling this
action — the action itself does not perform a checkout.

## Inputs

| Name       | Required | Description                                                         |
|------------|----------|---------------------------------------------------------------------|
| `base-sha` | No       | The base commit SHA to diff from. Defaults to `github.event.before` |
| `head-sha` | No       | The head commit SHA to diff to. Defaults to `github.sha`.           |

## Outputs

| Name            | Description                                                              |
|-----------------|--------------------------------------------------------------------------|
| `files_changed` | `"true"` if any changed file is not export-ignored, otherwise `"false"`. |

## `.gitattributes` pattern notes

A directory-only pattern without a glob, e.g. `docs export-ignore` or `docs/ export-ignore`,
excludes everything under `docs/` — this action replicates `git archive`'s tree-pruning behavior
for such patterns. If you also want to un-ignore a specific file inside that directory with a
negation rule (`-export-ignore`), it will have **no effect**: once a directory itself matches
`export-ignore`, `git archive` (and this action) never looks at more specific rules inside it.

```gitattributes
docs export-ignore
docs/keep-me.txt -export-ignore   # ignored: docs/ already excludes everything below it
```

To make a per-file exception work, write the broad rule as a recursive glob (`docs/**`) instead,
which matches each file individually rather than pruning the whole directory:

```gitattributes
docs/** export-ignore
docs/keep-me.txt -export-ignore       # works: docs/** matches files individually
```

This only works one level deep, though. `docs/**` also matches subdirectories under `docs/` as
tree entries in their own right, so a negation for a file further down still gets pruned before
it's ever evaluated:

```gitattributes
docs/** export-ignore
docs/sub/keep-me.txt -export-ignore   # ignored: docs/sub itself already matches docs/**
```

## Job summary

The action writes a human-readable summary of the changed files to the job's
[GitHub Actions summary page](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#adding-a-job-summary).

## Development

Each test case builds a throwaway git repository from the fixtures in `test/cases/` and
exercises `scripts/check-export-ignore.sh` directly. Run a single case by name:

```bash
test/run-test-case.sh 01-non-ignored-change
```

Run all cases:

```bash
for case_dir in test/cases/*/; do test/run-test-case.sh "$(basename "$case_dir")"; done
```

## License

MIT, see [LICENSE](LICENSE).
