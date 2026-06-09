#!/usr/bin/env bats
# layer-classify.bats
# Unit tests for classify_path in layer-classify.sh.
# Each test calls classify_path in an isolated subshell so the lib is
# sourced fresh and git state does not matter.

load helpers

# ---------------------------------------------------------------------------
# Spec patterns
# ---------------------------------------------------------------------------

@test "classify_path: spec/foo_spec.rb -> spec" {
  result=$(run_classify_path "spec/foo_spec.rb")
  [ "$result" = "spec" ]
}

@test "classify_path: app/controllers/users_controller_test.rb -> spec" {
  result=$(run_classify_path "app/controllers/users_controller_test.rb")
  [ "$result" = "spec" ]
}

@test "classify_path: __tests__/components/Button.test.tsx -> spec" {
  result=$(run_classify_path "__tests__/components/Button.test.tsx")
  [ "$result" = "spec" ]
}

@test "classify_path: features/login.feature -> spec" {
  result=$(run_classify_path "features/login.feature")
  [ "$result" = "spec" ]
}

# ---------------------------------------------------------------------------
# Backend patterns
# ---------------------------------------------------------------------------

@test "classify_path: app/controllers/users_controller.rb -> backend" {
  result=$(run_classify_path "app/controllers/users_controller.rb")
  [ "$result" = "backend" ]
}

@test "classify_path: app/services/session_service.go -> backend" {
  result=$(run_classify_path "app/services/session_service.go")
  [ "$result" = "backend" ]
}

# ---------------------------------------------------------------------------
# Frontend patterns
# ---------------------------------------------------------------------------

@test "classify_path: app/javascript/components/Foo.jsx -> frontend" {
  result=$(run_classify_path "app/javascript/components/Foo.jsx")
  [ "$result" = "frontend" ]
}

@test "classify_path: styles/main.scss -> frontend" {
  result=$(run_classify_path "styles/main.scss")
  [ "$result" = "frontend" ]
}

# ---------------------------------------------------------------------------
# Migration patterns
# ---------------------------------------------------------------------------

@test "classify_path: db/migrate/20260101_add_x.rb -> migration" {
  result=$(run_classify_path "db/migrate/20260101_add_x.rb")
  [ "$result" = "migration" ]
}

@test "classify_path: migrations/0001_initial.py -> migration" {
  result=$(run_classify_path "migrations/0001_initial.py")
  [ "$result" = "migration" ]
}

# ---------------------------------------------------------------------------
# Config patterns
# ---------------------------------------------------------------------------

@test "classify_path: Gemfile -> config" {
  result=$(run_classify_path "Gemfile")
  [ "$result" = "config" ]
}

@test "classify_path: package.json -> config" {
  result=$(run_classify_path "package.json")
  [ "$result" = "config" ]
}

@test "classify_path: .rubocop.yml -> config" {
  result=$(run_classify_path ".rubocop.yml")
  [ "$result" = "config" ]
}

# ---------------------------------------------------------------------------
# Docs patterns
# ---------------------------------------------------------------------------

@test "classify_path: README.md -> docs" {
  result=$(run_classify_path "README.md")
  [ "$result" = "docs" ]
}

@test "classify_path: docs/guide.rst -> docs" {
  result=$(run_classify_path "docs/guide.rst")
  [ "$result" = "docs" ]
}

# ---------------------------------------------------------------------------
# Other (catch-all)
# ---------------------------------------------------------------------------

@test "classify_path: .gitignore -> other" {
  result=$(run_classify_path ".gitignore")
  [ "$result" = "other" ]
}

@test "classify_path: Makefile -> other" {
  result=$(run_classify_path "Makefile")
  [ "$result" = "other" ]
}
