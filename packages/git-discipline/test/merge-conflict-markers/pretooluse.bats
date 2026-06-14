#!/usr/bin/env bats
# packages/git-discipline/test/merge-conflict-markers/pretooluse.bats
#
# PreToolUse:Bash layer for the conflict-marker guard. Drives hooks/dispatch.sh
# against a real repo left mid-merge, asserting that a merge-finalizing command
# is denied while markers remain and passes once the tree is clean.

load helpers

@test "git commit with conflict markers in working tree is denied, naming the file" {
  seed_conflict
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]
}

@test "git merge --continue with conflict markers is denied" {
  seed_conflict
  run_dispatch_in_repo 'git merge --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git rebase --continue with conflict markers is denied" {
  seed_conflict
  run_dispatch_in_repo 'git rebase --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git cherry-pick --continue with conflict markers is denied" {
  seed_cherry_pick_conflict
  run_dispatch_in_repo 'git cherry-pick --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git am --continue with conflict markers is denied" {
  seed_conflict
  run_dispatch_in_repo 'git am --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git commit --amend with conflict markers is denied" {
  seed_conflict
  git -C "$TEST_REPO" add f.txt
  run_dispatch_in_repo 'git commit --amend --no-edit'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "starting a merge (no --continue) is not a finalizing command, passes silently" {
  seed_conflict
  run_dispatch_in_repo 'git merge sidebranch'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "a hand-pasted conflict block (no merge in progress) is denied on commit" {
  seed_pasted_markers
  run_dispatch_in_repo 'git commit -m "land it"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]
}

@test "GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS set to a non-1 value does not escape" {
  seed_conflict
  export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=true
  run_dispatch_in_repo 'git commit -m "resolve"'
  unset GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git commit with markers staged (the add-then-commit case) is denied" {
  seed_conflict
  git -C "$TEST_REPO" add f.txt   # stage the still-conflicted file
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]
}

@test "git commit after a clean resolution passes" {
  seed_conflict
  resolve_clean
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "markdown ======= underline of non-conflict length does not trip the guard" {
  seed_conflict
  resolve_clean
  # 9-equals setext underline: not a 7-char conflict separator.
  printf 'Heading\n=========\nbody\n' > "$TEST_REPO/notes.md"
  git -C "$TEST_REPO" add notes.md
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "magic-comment escape allows the commit despite markers" {
  seed_conflict
  run_dispatch_in_repo 'git commit -m "resolve" # allow-conflict-markers'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "exported env-var escape allows the commit despite markers" {
  seed_conflict
  export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1
  run_dispatch_in_repo 'git commit -m "resolve"'
  unset GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "non-commit git command passes silently" {
  seed_conflict
  run_dispatch_in_repo 'git status'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}
