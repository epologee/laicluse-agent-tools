#!/usr/bin/env bats
# packages/git-discipline/test/repo-deny/mutations-blocked.bats
#
# With the sentinel present, every mutation is blocked with exit 2 and the
# `[git-discipline/disable-git]` prefix.

load helpers

@test "lock blocks git commit" {
  write_sentinel "test"
  run_dispatch 'git commit -m foo'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/disable-git]"* ]]
}

@test "lock blocks git checkout" {
  write_sentinel
  run_dispatch 'git checkout main'
  [ "$status" -eq 2 ]
}

@test "lock blocks git switch" {
  write_sentinel
  run_dispatch 'git switch -c topic'
  [ "$status" -eq 2 ]
}

@test "lock blocks git restore" {
  write_sentinel
  run_dispatch 'git restore .'
  [ "$status" -eq 2 ]
}

@test "lock blocks git reset" {
  write_sentinel
  run_dispatch 'git reset --hard HEAD'
  [ "$status" -eq 2 ]
}

@test "lock blocks git add" {
  write_sentinel
  run_dispatch 'git add .'
  [ "$status" -eq 2 ]
}

@test "lock blocks git push" {
  write_sentinel
  run_dispatch 'git push'
  [ "$status" -eq 2 ]
}

@test "lock blocks git merge" {
  write_sentinel
  run_dispatch 'git merge other'
  [ "$status" -eq 2 ]
}

@test "lock blocks git rebase" {
  write_sentinel
  run_dispatch 'git rebase main'
  [ "$status" -eq 2 ]
}

@test "lock blocks bare git stash (which means stash push)" {
  write_sentinel
  run_dispatch 'git stash'
  [ "$status" -eq 2 ]
}

@test "lock blocks git branch -d" {
  write_sentinel
  run_dispatch 'git branch -d topic'
  [ "$status" -eq 2 ]
}

@test "lock blocks git branch --set-upstream-to" {
  write_sentinel
  run_dispatch 'git branch --set-upstream-to=origin/main'
  [ "$status" -eq 2 ]
}

@test "lock blocks git tag v0.1" {
  write_sentinel
  run_dispatch 'git tag v0.1'
  [ "$status" -eq 2 ]
}

@test "lock blocks git remote add" {
  write_sentinel
  run_dispatch 'git remote add origin https://example.com/x.git'
  [ "$status" -eq 2 ]
}

@test "lock blocks git config --unset" {
  write_sentinel
  run_dispatch 'git config --unset user.email'
  [ "$status" -eq 2 ]
}

@test "lock blocks git bisect start" {
  write_sentinel
  run_dispatch 'git bisect start'
  [ "$status" -eq 2 ]
}

@test "lock blocks git bisect visualize (gitk GUI)" {
  write_sentinel
  run_dispatch 'git bisect visualize'
  [ "$status" -eq 2 ]
}

@test "lock blocks git -c user.email=x commit (global flag stripped)" {
  write_sentinel
  run_dispatch 'git -c user.email=x commit -m foo'
  [ "$status" -eq 2 ]
}
