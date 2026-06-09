#!/usr/bin/env bats
# dry-run.bats
# --dry-run prints actions but writes nothing to disk.

load helpers

@test "--dry-run prints would-install actions" {
  run_install "$TEST_REPO" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  [[ "$output" == *"would install commit-msg"* ]]
  [[ "$output" == *"would install post-commit"* ]]
}

@test "--dry-run does not write any files" {
  run_install "$TEST_REPO" --dry-run

  [ "$status" -eq 0 ]
  [ ! -f "$(hook_target_path commit-msg)" ]
  [ ! -f "$(hook_target_path post-commit)" ]
}
