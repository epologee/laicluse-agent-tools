#!/usr/bin/env bats
# packages/git-discipline/test/migrated-hooks/git-dash-c.bats
#
# Verifies the absorbed ~/.claude/hooks/block-git-dash-c.sh behaviour now
# lives in guards/git-dash-c.sh:
#
#   - `git -C <dir> ...` is denied with the git-dash-c mnemonic and the
#     suggested `cd <dir>` rewrite in the message.
#   - Plain `git status` (no -C) passes silently.
#   - Lowercase `-c` (config override) is unaffected.
#   - `-C` later in the command line is unaffected (the guard only blocks at
#     the start position, matching the original regex anchor).

load helpers

@test "git -C /tmp/foo status is denied with git-dash-c mnemonic" {
  run_dispatch 'git -C /tmp/foo status'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/git-dash-c]"* ]]
  [[ "$output" == *"cd /tmp/foo"* ]]
}

@test "plain git status passes silently" {
  run_dispatch 'git status'

  [ "$status" -eq 0 ]
  [[ "$output" != *"git-dash-c"* ]]
}

@test "lowercase git -c color.ui=always log passes silently" {
  run_dispatch 'git -c color.ui=always log'

  [ "$status" -eq 0 ]
  [[ "$output" != *"git-dash-c"* ]]
}

@test "git -C \$HOME/foo is denied with the home prefix rewritten to ~" {
  run_dispatch "git -C $HOME/foo status"

  [ "$status" -eq 2 ]
  [[ "$output" == *"cd ~/foo"* ]]
  [[ "$output" != *"cd $HOME/foo"* ]]
}

@test "git status with -C later in the command passes silently" {
  # The original regex was anchored at ^git -C, so a -C as a value to a later
  # flag is not blocked. We pass `--grep=-C` as a benign placeholder; the
  # guard must not fire.
  run_dispatch 'git log --grep=-C'

  [ "$status" -eq 0 ]
  [[ "$output" != *"git-dash-c"* ]]
}
