#!/usr/bin/env bats
# Malformed input edge cases: empty file, file does not exist.

load helpers

# ---------------------------------------------------------------------------
# Malformed input (2 cases)
# ---------------------------------------------------------------------------

@test "empty commit message file exits 2 non-blocking" {
  local file
  file=$(write_fixture "empty.txt" "")

  run invoke_validator "$file"
  [ "$status" -eq 2 ]
  [[ "$output" == *"empty-message"* ]]
}

@test "nonexistent file exits 2 non-blocking" {
  local file="$TMPDIR_TEST/does-not-exist.txt"

  run invoke_validator "$file"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unreadable-file"* ]]
}
