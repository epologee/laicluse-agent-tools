#!/usr/bin/env bats
# template-validate-roundtrip.bats
# Cross-layer integration: verify that every Slice value produced by
# suggest_slice passes the validate_body slice-length rule.
#
# Goal: guard against the regression where suggest_slice emits a token
# shorter than 10 chars (e.g. "backend", "frontend") that then fails the
# free-text slice-too-short rule introduced by Fix 3 + Fix 9 interaction.
#
# Strategy: for each layer-classification scenario we call suggest_slice
# directly (same path that prepare-commit-msg takes) and assert the result
# is either a known opt-out enum token or >= 10 chars. No real git repo
# is required; the classification and suggestion logic is pure shell.

# Opt-out tokens that validate-body.sh exempts from the 10-char length rule.
_OPT_OUT_TOKENS="docs-only config-only migration-only spec-only chore-deps revert merge wip"

# _classify_lib_path: resolve CLASSIFY_LIB from BATS_TEST_FILENAME at runtime.
# Top-level variable expansion in bats runs in a tmpdir where BASH_SOURCE[0]
# resolves incorrectly; BATS_TEST_FILENAME is set correctly by bats-core.
_classify_lib_path() {
  local test_dir
  test_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  printf '%s' "$test_dir/../../hooks/lib/layer-classify.sh"
}

# _slice_for_paths <newline-separated-paths>
# Pipes paths through classify_diff then suggest_slice and prints the result.
_slice_for_paths() {
  local paths="$1"
  local lib
  lib="$(_classify_lib_path)"
  printf '%s\n' "$paths" | bash -c "
    source '$lib'
    summary=\$(classify_diff)
    suggest_slice \"\$summary\"
  "
}

# _assert_valid_slice <slice_value>
# Fails the test if the value is neither an opt-out token nor >= 10 chars.
_assert_valid_slice() {
  local val="$1"
  local tok
  for tok in $_OPT_OUT_TOKENS; do
    [[ "$val" = "$tok" ]] && return 0
  done
  if [[ "${#val}" -lt 10 ]]; then
    echo "slice-too-short: '$val' is ${#val} chars (need >= 10 or opt-out token)" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Single-layer scenarios
# ---------------------------------------------------------------------------

@test "roundtrip: spec-only path -> suggest_slice -> opt-out token" {
  local slice
  slice=$(_slice_for_paths "spec/models/user_spec.rb")
  [ "$slice" = "spec-only" ]
  _assert_valid_slice "$slice"
}

@test "roundtrip: docs-only path -> suggest_slice -> opt-out token" {
  local slice
  slice=$(_slice_for_paths "README.md")
  [ "$slice" = "docs-only" ]
  _assert_valid_slice "$slice"
}

@test "roundtrip: config-only path -> suggest_slice -> opt-out token" {
  local slice
  slice=$(_slice_for_paths "config/database.yml")
  [ "$slice" = "config-only" ]
  _assert_valid_slice "$slice"
}

@test "roundtrip: migration-only path -> suggest_slice -> opt-out token" {
  local slice
  slice=$(_slice_for_paths "db/migrate/20260101_add_user_id.rb")
  [ "$slice" = "migration-only" ]
  _assert_valid_slice "$slice"
}

@test "roundtrip: unmatched path -> suggest_slice -> chore-deps opt-out token" {
  # A file with no recognised extension hits the 'other' bucket -> chore-deps.
  local slice
  slice=$(_slice_for_paths "some-unknown-binary")
  [ "$slice" = "chore-deps" ]
  _assert_valid_slice "$slice"
}

@test "roundtrip: lockfile path -> suggest_slice -> passes validation (config-only)" {
  # Gemfile.lock matches the config regex (.lock$), so suggest_slice returns
  # config-only, which is an opt-out token and passes slice validation.
  local slice
  slice=$(_slice_for_paths "Gemfile.lock")
  [ "$slice" = "config-only" ]
  _assert_valid_slice "$slice"
}

@test "roundtrip: backend-only path -> suggest_slice -> value >= 10 chars" {
  local slice
  slice=$(_slice_for_paths "app/models/session.rb")
  # Must not be a short bare token.
  _assert_valid_slice "$slice"
  # Concretely: "backend layer" (13 chars).
  [ "$slice" = "backend layer" ]
}

@test "roundtrip: frontend-only path -> suggest_slice -> value >= 10 chars" {
  local slice
  slice=$(_slice_for_paths "app/javascript/components/Session.tsx")
  _assert_valid_slice "$slice"
  # Concretely: "frontend layer" (14 chars).
  [ "$slice" = "frontend layer" ]
}

# ---------------------------------------------------------------------------
# Multi-layer scenarios (all produce " + "-joined strings >= 10 chars)
# ---------------------------------------------------------------------------

@test "roundtrip: backend + spec paths -> suggest_slice -> value >= 10 chars" {
  local slice
  slice=$(_slice_for_paths "$(printf 'app/models/session.rb\nspec/models/session_spec.rb')")
  _assert_valid_slice "$slice"
  [ "$slice" = "backend + spec" ]
}

@test "roundtrip: frontend + backend + spec paths -> suggest_slice -> value >= 10 chars" {
  local slice
  slice=$(_slice_for_paths "$(printf 'app/javascript/components/Session.tsx\napp/models/session.rb\nspec/models/session_spec.rb')")
  _assert_valid_slice "$slice"
  [ "$slice" = "backend + frontend + spec" ]
}
