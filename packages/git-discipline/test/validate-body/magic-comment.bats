#!/usr/bin/env bats
# The legacy `# vsd-skip: <reason>` magic comment is no longer an escape.
# The strict commit-discipline rules apply to every commit; the magic
# comment is always rejected with vsd-skip-removed so commits that relied
# on it surface clearly instead of silently passing.

load helpers

@test "vsd-skip with a reason is rejected with vsd-skip-removed" {
  local body
  body="$(cat <<'MSG'
Expose session endpoint

# vsd-skip: one-line hotfix pushed under time pressure
MSG
)"
  local file
  file=$(write_fixture "vsd-skip-with-reason.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"vsd-skip-removed"* ]]
}

@test "bare vsd-skip without reason is rejected with vsd-skip-removed" {
  local body
  body="$(cat <<'MSG'
Expose session endpoint

# vsd-skip:
MSG
)"
  local file
  file=$(write_fixture "vsd-skip-bare.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"vsd-skip-removed"* ]]
}

@test "vsd-skip on a UI-touched commit is rejected with vsd-skip-removed" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  local body
  body="$(cat <<'MSG'
Render onboarding banner above tab strip

# vsd-skip: visual evidence lands later
MSG
)"
  local file
  file=$(write_fixture "vsd-skip-ui.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"vsd-skip-removed"* ]]
}
