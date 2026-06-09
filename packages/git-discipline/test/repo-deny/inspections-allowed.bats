#!/usr/bin/env bats
# packages/git-discipline/test/repo-deny/inspections-allowed.bats
#
# Even with the sentinel present, read-only inspection commands continue to
# pass. The full allow-list lives in hooks/guards/repo-deny.sh.

load helpers

@test "lock allows git status" {
  write_sentinel
  run_dispatch 'git status'
  [ "$status" -eq 0 ]
}

@test "lock allows git log" {
  write_sentinel
  run_dispatch 'git log --oneline'
  [ "$status" -eq 0 ]
}

@test "lock allows git diff" {
  write_sentinel
  run_dispatch 'git diff'
  [ "$status" -eq 0 ]
}

@test "lock allows git show HEAD" {
  write_sentinel
  run_dispatch 'git show HEAD'
  [ "$status" -eq 0 ]
}

@test "lock allows git rev-parse" {
  write_sentinel
  run_dispatch 'git rev-parse HEAD'
  [ "$status" -eq 0 ]
}

@test "lock allows git blame" {
  write_sentinel
  run_dispatch 'git blame README'
  [ "$status" -eq 0 ]
}

@test "lock allows bare git branch (list)" {
  write_sentinel
  run_dispatch 'git branch'
  [ "$status" -eq 0 ]
}

@test "lock allows bare git tag (list)" {
  write_sentinel
  run_dispatch 'git tag'
  [ "$status" -eq 0 ]
}

@test "lock allows git stash list" {
  write_sentinel
  run_dispatch 'git stash list'
  [ "$status" -eq 0 ]
}

@test "lock allows git remote -v (read form)" {
  write_sentinel
  run_dispatch 'git remote -v'
  [ "$status" -eq 0 ]
}

@test "lock allows git config --get" {
  write_sentinel
  run_dispatch 'git config --get user.email'
  [ "$status" -eq 0 ]
}

@test "lock allows git -c foo=bar status (global flag stripped, then status)" {
  write_sentinel
  run_dispatch 'git -c foo=bar status'
  [ "$status" -eq 0 ]
}

@test "lock allows git bisect view" {
  write_sentinel
  run_dispatch 'git bisect view'
  [ "$status" -eq 0 ]
}

@test "lock allows git archive (writes outside repo, does not mutate state)" {
  write_sentinel
  run_dispatch 'git archive --format=tar HEAD'
  [ "$status" -eq 0 ]
}
