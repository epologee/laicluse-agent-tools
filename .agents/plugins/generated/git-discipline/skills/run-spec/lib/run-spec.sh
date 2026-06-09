#!/bin/bash
# packages/git-discipline/skills/run-spec/lib/run-spec.sh
# Runner detection and execution for /git-discipline:run-spec.
# Sourced by the SKILL.md execution context and by BATS tests.
# Never executed directly; the caller is responsible for set -euo pipefail.
#
# Public functions:
#   run_spec_detect_runner <project-root>  -> echoes runner command prefix
#   run_spec_run <spec-path> [project-root] -> runs test, prints PASS/FAIL,
#                                              exits with test runner exit code

# ---------------------------------------------------------------------------
# run_spec_detect_runner <project-root>
# Echoes the runner command prefix (e.g. "bundle exec rspec").
# Returns 1 if no runner could be detected.
# ---------------------------------------------------------------------------
run_spec_detect_runner() {
  local root="${1:-.}"

  # Allow explicit override.
  if [[ -n "${GIT_DISCIPLINE_TEST_RUNNER:-}" ]]; then
    printf '%s' "$GIT_DISCIPLINE_TEST_RUNNER"
    return 0
  fi

  # Go: go.mod present.
  if [[ -f "$root/go.mod" ]]; then
    printf 'go test'
    return 0
  fi

  # Ruby: Gemfile or .rspec.
  if [[ -f "$root/Gemfile" || -f "$root/.rspec" ]]; then
    if command -v bundle >/dev/null 2>&1; then
      printf 'bundle exec rspec'
    else
      printf 'rspec'
    fi
    return 0
  fi

  # Node: package.json with jest or vitest.
  if [[ -f "$root/package.json" ]]; then
    if grep -q '"jest"' "$root/package.json" 2>/dev/null; then
      printf 'npx jest'
      return 0
    fi
    if grep -q '"vitest"' "$root/package.json" 2>/dev/null; then
      printf 'npx vitest run'
      return 0
    fi
  fi

  # Python: pyproject.toml, pytest.ini, or setup.cfg with [tool:pytest].
  if [[ -f "$root/pyproject.toml" || -f "$root/pytest.ini" || -f "$root/setup.cfg" ]]; then
    printf 'pytest'
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# run_spec_run <spec-path> [project-root]
# Detects runner, runs the spec, prints PASS/FAIL summary.
# Exits with the test runner's exit code. No cache side-effects.
# ---------------------------------------------------------------------------
run_spec_run() {
  local spec_path="$1"
  local project_root="${2:-.}"

  if [[ -z "$spec_path" ]]; then
    printf 'run-spec: spec path argument is required\n' >&2
    exit 1
  fi

  local runner
  if ! runner=$(run_spec_detect_runner "$project_root"); then
    printf 'run-spec: could not detect test runner.\n' >&2
    printf 'Set GIT_DISCIPLINE_TEST_RUNNER to the runner command (e.g. "bundle exec rspec").\n' >&2
    exit 1
  fi

  # Run the test.
  local test_exit=0
  $runner "$spec_path"
  test_exit=$?

  if [[ "$test_exit" -eq 0 ]]; then
    printf 'PASS  %s  (exit 0)\n' "$spec_path"
  else
    printf 'FAIL  %s  (exit %s)\n' "$spec_path" "$test_exit"
  fi

  exit "$test_exit"
}
