#!/usr/bin/env bats
# worktree.bats
# In a git worktree, install.sh detects the worktree's gitdir (not the main
# repo's) and lands hooks there.

load helpers

@test "worktree install lands in the worktree's gitdir" {
  # Need an initial commit before adding a worktree.
  pushd "$TEST_REPO" >/dev/null
  printf 'init\n' > README
  git add README
  git -c commit.gpgsign=false commit -q -m "init" --no-verify
  popd >/dev/null

  local worktree_dir="$BATS_TEST_TMPDIR/wt"
  pushd "$TEST_REPO" >/dev/null
  git worktree add -b feature/wt "$worktree_dir" >/dev/null
  popd >/dev/null

  run_install "$worktree_dir"
  [ "$status" -eq 0 ]

  # The worktree's gitdir is .git/worktrees/wt under the main repo, NOT
  # the main .git/hooks/. Verify the install landed in the worktree-specific
  # hooks dir, which "git rev-parse --git-dir" returns from inside the wt.
  pushd "$worktree_dir" >/dev/null
  local gitdir
  gitdir=$(git rev-parse --git-dir)
  # Resolve to absolute.
  gitdir=$(cd "$gitdir" && pwd)
  popd >/dev/null

  [ -f "$gitdir/hooks/commit-msg" ]
  [ -f "$gitdir/hooks/post-commit" ]
}
