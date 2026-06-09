#!/usr/bin/env bats
# core-hookspath.bats
# When the repo has core.hooksPath set, install.sh writes to that directory
# rather than .git/hooks/.

load helpers

@test "core.hooksPath redirects the install target" {
  pushd "$TEST_REPO" >/dev/null
  git config core.hooksPath .githooks
  popd >/dev/null

  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  [ -f "$TEST_REPO/.githooks/commit-msg" ]
  [ -f "$TEST_REPO/.githooks/post-commit" ]
  [ ! -f "$TEST_REPO/.git/hooks/commit-msg" ]
}

@test "summary mentions core.hooksPath as the hooks dir" {
  pushd "$TEST_REPO" >/dev/null
  git config core.hooksPath .githooks
  popd >/dev/null

  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  [[ "$output" == *"core.hooksPath"* ]]
  [[ "$output" == *".githooks"* ]]
}
