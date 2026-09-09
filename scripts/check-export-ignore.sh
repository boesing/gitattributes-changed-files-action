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

# A directory-only export-ignore pattern (e.g. "docs/", "/docs" or "docs") never matches a nested file's
# own path via `git check-attr` — only `git archive`'s tree walk applies it to the directory entry
# itself and prunes the whole subtree. To get the same result, every ancestor directory (queried
# with a trailing slash) must be checked too, not just the changed file's own path.
is_export_ignored() {
  local path="$1" dir
  if git check-attr export-ignore -- "$path" | grep -q ': export-ignore: set$'; then
    return 0
  fi
  dir="$(dirname "$path")"
  while [ "$dir" != "." ]; do
    if git check-attr export-ignore -- "${dir}/" | grep -q ': export-ignore: set$'; then
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

not_ignored=""
while IFS= read -r file; do
  if ! is_export_ignored "$file"; then
    not_ignored="${not_ignored}${file}"$'\n'
  fi
done <<<"$changed_files"
not_ignored="${not_ignored%$'\n'}"

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
  echo "$not_ignored" | sed 's/^/- /'
} >>"$GITHUB_STEP_SUMMARY"
