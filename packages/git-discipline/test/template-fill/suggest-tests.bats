#!/usr/bin/env bats
# suggest-tests.bats
# Unit tests for suggest_tests in layer-classify.sh.
# The function reads paths from stdin and emits only spec-pattern paths,
# comma-separated on one line.

load helpers

# Helper: write paths as separate args to a temp file, pipe through suggest_tests.
_tests() {
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$@" > "$tmp"
  bash -c "source '$CLASSIFY_LIB'; suggest_tests < '$tmp'"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Mixed input
# ---------------------------------------------------------------------------

@test "suggest_tests: mixed list emits only spec paths" {
  result=$(_tests "app/services/session_service.rb" "spec/services/session_service_spec.rb" "README.md")
  [ "$result" = "spec/services/session_service_spec.rb" ]
}

@test "suggest_tests: multiple spec paths are comma-separated" {
  result=$(_tests "spec/controllers/foo_spec.rb" "app/controllers/foo.rb" "spec/models/bar_spec.rb")
  [ "$result" = "spec/controllers/foo_spec.rb, spec/models/bar_spec.rb" ]
}

# ---------------------------------------------------------------------------
# No spec paths
# ---------------------------------------------------------------------------

@test "suggest_tests: no spec paths -> empty output" {
  result=$(_tests "app/models/user.rb" "db/migrate/20260101_add_users.rb")
  [ -z "$result" ]
}

@test "suggest_tests: docs-only input -> empty output" {
  result=$(_tests "README.md")
  [ -z "$result" ]
}
