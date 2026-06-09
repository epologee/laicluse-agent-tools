#!/usr/bin/env bats
# suggest-slice.bats
# Unit tests for suggest_slice in layer-classify.sh.

load helpers

_slice() {
  bash -c "source '$CLASSIFY_LIB'; suggest_slice '$1'"
}

# ---------------------------------------------------------------------------
# Single-layer opt-outs
# ---------------------------------------------------------------------------

@test "suggest_slice: 'docs' -> 'docs-only'" {
  result=$(_slice "docs")
  [ "$result" = "docs-only" ]
}

@test "suggest_slice: 'config' -> 'config-only'" {
  result=$(_slice "config")
  [ "$result" = "config-only" ]
}

@test "suggest_slice: 'migration' -> 'migration-only'" {
  result=$(_slice "migration")
  [ "$result" = "migration-only" ]
}

@test "suggest_slice: 'spec' -> 'spec-only'" {
  result=$(_slice "spec")
  [ "$result" = "spec-only" ]
}

@test "suggest_slice: 'other' -> 'chore-deps'" {
  result=$(_slice "other")
  [ "$result" = "chore-deps" ]
}

# ---------------------------------------------------------------------------
# Multi-layer combinations
# ---------------------------------------------------------------------------

@test "suggest_slice: 'backend' -> 'backend layer' (padded to >= 10 chars)" {
  result=$(_slice "backend")
  [ "$result" = "backend layer" ]
}

@test "suggest_slice: 'frontend' -> 'frontend layer' (padded to >= 10 chars)" {
  result=$(_slice "frontend")
  [ "$result" = "frontend layer" ]
}

@test "suggest_slice: 'backend spec' -> 'backend + spec'" {
  result=$(_slice "backend spec")
  [ "$result" = "backend + spec" ]
}

@test "suggest_slice: 'backend frontend spec' -> 'backend + frontend + spec'" {
  result=$(_slice "backend frontend spec")
  [ "$result" = "backend + frontend + spec" ]
}

@test "suggest_slice: 'backend migration spec' -> 'backend + migration + spec'" {
  result=$(_slice "backend migration spec")
  [ "$result" = "backend + migration + spec" ]
}

@test "suggest_slice outputs all satisfy validate-body >= 10 chars or are opt-out tokens" {
  # All single-layer and multi-layer outputs that reach the free-text path
  # must be >= 10 chars to pass the slice-too-short rule.
  local opt_out="docs-only config-only migration-only spec-only chore-deps"

  check_output() {
    local summary="$1"
    local result
    result=$(bash -c "source '$CLASSIFY_LIB'; suggest_slice '$summary'")
    # If result is an opt-out token, it is exempt.
    local tok
    for tok in $opt_out; do
      [[ "$result" = "$tok" ]] && return 0
    done
    # Otherwise must be >= 10 chars.
    [ "${#result}" -ge 10 ]
  }

  check_output "docs"
  check_output "config"
  check_output "migration"
  check_output "spec"
  check_output "other"
  check_output "backend"
  check_output "frontend"
  check_output "backend spec"
  check_output "frontend backend spec"
  check_output "backend migration spec"
}
