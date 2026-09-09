#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <case-name>" >&2
  echo "  <case-name> is a directory name under test/cases/, e.g. 01-non-ignored-change" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
check_script="$repo_root/scripts/check-export-ignore.sh"
case_dir="$script_dir/cases/$1"

if [ ! -d "$case_dir" ]; then
  echo "Error: no such test case: $case_dir" >&2
  exit 1
fi

case_name="$(basename "$case_dir")"
base_dir="${case_dir}/base"
head_dir="${case_dir}/head"
expected_file="${case_dir}/expected.json"
base_sha_override_file="${case_dir}/base-sha-override"

work_dir="$(mktemp -d)"

git init --quiet "$work_dir"
git -C "$work_dir" config user.email "test@example.com"
git -C "$work_dir" config user.name "Test"
git -C "$work_dir" config commit.gpgsign "false"

base_sha=""
if [ -d "$base_dir" ]; then
  cp -a "$base_dir/." "$work_dir/"
  git -C "$work_dir" add -A
  git -C "$work_dir" commit --quiet -m "base"
  base_sha="$(git -C "$work_dir" rev-parse HEAD)"
  find "$work_dir" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
fi

cp -a "$head_dir/." "$work_dir/"
git -C "$work_dir" add -A
git -C "$work_dir" commit --quiet -m "head"
head_sha="$(git -C "$work_dir" rev-parse HEAD)"

input_base_sha="$base_sha"
if [ -f "$base_sha_override_file" ]; then
  input_base_sha="$(cat "$base_sha_override_file")"
fi

output_file="$(mktemp)"
summary_file="$(mktemp)"

(
  cd "$work_dir"
  INPUT_BASE_SHA="$input_base_sha" INPUT_HEAD_SHA="$head_sha" \
    GITHUB_OUTPUT="$output_file" GITHUB_STEP_SUMMARY="$summary_file" \
    "$check_script"
)

actual_files_changed="$(grep '^files_changed=' "$output_file" | cut -d= -f2)"
expected_files_changed="$(jq -r '.files_changed' "$expected_file")"

rm -rf "$work_dir" "$output_file" "$summary_file"

if [ "$actual_files_changed" = "$expected_files_changed" ]; then
  echo "PASS: $case_name"
  exit 0
fi

echo "FAIL: $case_name (expected files_changed=$expected_files_changed, got $actual_files_changed)"
exit 1
