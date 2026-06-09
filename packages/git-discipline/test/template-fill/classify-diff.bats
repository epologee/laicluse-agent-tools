#!/usr/bin/env bats
# classify-diff.bats
# Unit tests for classify_diff in layer-classify.sh.
# Output is a sorted space-separated summary of layers present.

load helpers

# Helper: pipe a literal newline-separated list through classify_diff.
# Paths are written to a temp file so embedded newlines survive the subshell
# boundary without quoting issues.
_diff() {
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$@" > "$tmp"
  bash -c "source '$CLASSIFY_LIB'; classify_diff < '$tmp'"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Single layers
# ---------------------------------------------------------------------------

@test "classify_diff: only docs paths -> 'docs'" {
  result=$(_diff "README.md" "docs/guide.md")
  [ "$result" = "docs" ]
}

@test "classify_diff: only migration paths -> 'migration'" {
  result=$(_diff "db/migrate/20260101_add_x.rb")
  [ "$result" = "migration" ]
}

@test "classify_diff: only config paths -> 'config'" {
  result=$(_diff "Gemfile")
  [ "$result" = "config" ]
}

@test "classify_diff: only spec paths -> 'spec'" {
  result=$(_diff "spec/foo_spec.rb" "spec/bar_spec.rb")
  [ "$result" = "spec" ]
}

# ---------------------------------------------------------------------------
# Multiple layers
# ---------------------------------------------------------------------------

@test "classify_diff: frontend + backend + spec -> 'backend frontend spec' (sorted)" {
  result=$(_diff "app/javascript/session.js" "app/controllers/sessions_controller.rb" "spec/controllers/sessions_controller_spec.rb")
  [ "$result" = "backend frontend spec" ]
}

@test "classify_diff: backend + spec -> 'backend spec'" {
  result=$(_diff "app/services/session_service.rb" "spec/services/session_service_spec.rb")
  [ "$result" = "backend spec" ]
}

@test "classify_diff: backend + migration -> 'backend migration'" {
  result=$(_diff "app/models/user.rb" "db/migrate/20260101_add_users.rb")
  [ "$result" = "backend migration" ]
}

@test "classify_diff: mixed with docs -> all layers appear" {
  result=$(_diff "app/services/foo.rb" "spec/services/foo_spec.rb" "README.md")
  [ "$result" = "backend docs spec" ]
}
