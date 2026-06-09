#!/usr/bin/env bats
# packages/git-discipline/test/repo-deny/sentinel-absent-allows.bats
#
# Without the per-repo sentinel, repo-deny is a no-op and the dispatcher
# proceeds normally.

load helpers

@test "no sentinel: git commit passes through repo-deny" {
  run_dispatch 'git commit --allow-empty -m "test commit" # ack-rule4:essentie'
  # Other guards may produce output but rc must not be the repo-deny prefix.
  [[ "$output" != *"[git-discipline/disable-git]"* ]]
}

@test "no sentinel: git checkout is allowed" {
  run_dispatch 'git checkout -b test-branch'
  [ "$status" -eq 0 ]
}

@test "no sentinel: git status is allowed" {
  run_dispatch 'git status'
  [ "$status" -eq 0 ]
}
