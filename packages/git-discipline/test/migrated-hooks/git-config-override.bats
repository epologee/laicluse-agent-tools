#!/usr/bin/env bats

load helpers

@test "git -c user.email=foo@bar commit is denied with git-config-override" {
  run_dispatch 'git -c user.email=foo@bar.com -c user.name=Foo commit -m "x"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/git-config-override]"* ]]
}

@test "plain git status passes silently" {
  run_dispatch 'git status'

  [ "$status" -eq 0 ]
  [[ "$output" != *"git-config-override"* ]]
}

@test "git -c color.ui=always log passes silently" {
  run_dispatch 'git -c color.ui=always log'

  [ "$status" -eq 0 ]
  [[ "$output" != *"git-config-override"* ]]
}

@test "git --config user.email=foo@bar.com commit is denied" {
  run_dispatch 'git --config user.email=foo@bar.com commit -m "x"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/git-config-override]"* ]]
}

@test "git -c user.name=Foo rebase is denied" {
  run_dispatch 'git -c user.name="Foo Bar" rebase main'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/git-config-override]"* ]]
}

@test "non-git command with -c user.email=foo is not affected" {
  run_dispatch 'echo "-c user.email=foo@bar.com"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"git-config-override"* ]]
}
