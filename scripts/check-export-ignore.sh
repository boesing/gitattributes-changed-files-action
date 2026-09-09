#!/usr/bin/env bash
set -euo pipefail

ZERO_SHA="0000000000000000000000000000000000000000"
EMPTY_TREE_SHA="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

head_sha="${INPUT_HEAD_SHA:-${EVENT_AFTER:-}}"

base_sha="${INPUT_BASE_SHA:-${EVENT_BEFORE:-}}"
if [ -z "$base_sha" ] || [ "$base_sha" = "$ZERO_SHA" ] || ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
  echo "Note: base commit is unavailable or unresolvable, comparing only the last commit (${head_sha}^)." >&2
  base_sha="${head_sha}^"
  if ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
    echo "Note: ${head_sha} has no parent commit, comparing against the empty tree instead." >&2
    base_sha="$EMPTY_TREE_SHA"
  fi
fi

changed_files="$(git diff --name-only "$base_sha" "$head_sha")"

if [ -z "$changed_files" ]; then
  echo "files_changed=false" >>"$GITHUB_OUTPUT"
  {
    echo "## Export-Ignore Change Check"
    echo
    echo "No files changed."
  } >>"$GITHUB_STEP_SUMMARY"
  exit 0
fi

not_ignored="$(echo "$changed_files" | git check-attr --stdin export-ignore | grep -v ': export-ignore: set$' || true)"

if [ -z "$not_ignored" ]; then
  echo "files_changed=false" >>"$GITHUB_OUTPUT"
  {
    echo "## Export-Ignore Change Check"
    echo
    echo "No files changed outside export-ignore paths."
  } >>"$GITHUB_STEP_SUMMARY"
  exit 0
fi

echo "files_changed=true" >>"$GITHUB_OUTPUT"
{
  echo "## Export-Ignore Change Check"
  echo
  echo "The following files changed outside export-ignore paths:"
  echo
  echo "$not_ignored" | sed -E 's/^(.*): export-ignore: .*$/- \1/'
} >>"$GITHUB_STEP_SUMMARY"
