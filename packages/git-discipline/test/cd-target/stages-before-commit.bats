#!/usr/bin/env bats
# allow-comment: dd_stages_before_commit spots a `git add`/`git stage` that runs in the same compound command as the commit. The PreToolUse gate fires before the command, so such a staging step has not run yet and its files are not in the index the validator reads; the detector lets the deny say so instead of a bare path-not-found.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  source "$SCRIPT_DIR/../../hooks/lib/common.sh"
}

@test "git add before commit is detected" {
  run dd_stages_before_commit 'git add foo.rb && git commit -m x'
  [ "$status" -eq 0 ]
}

@test "git add -A before commit is detected" {
  run dd_stages_before_commit 'git add -A && git commit -m x'
  [ "$status" -eq 0 ]
}

@test "git stage before commit is detected" {
  run dd_stages_before_commit 'git stage foo.rb && git commit -m x'
  [ "$status" -eq 0 ]
}

@test "git -C add before git -C commit is detected" {
  run dd_stages_before_commit 'git -C /repo add foo.rb && git -C /repo commit -m x'
  [ "$status" -eq 0 ]
}

@test "a bare commit is not flagged" {
  run dd_stages_before_commit 'git commit -m x'
  [ "$status" -ne 0 ]
}

@test "a cd prefix before commit is not flagged" {
  run dd_stages_before_commit 'cd /repo && git commit -m x'
  [ "$status" -ne 0 ]
}

@test "the word add inside the commit message does not count" {
  run dd_stages_before_commit "git commit -m 'git add support to the parser'"
  [ "$status" -ne 0 ]
}
