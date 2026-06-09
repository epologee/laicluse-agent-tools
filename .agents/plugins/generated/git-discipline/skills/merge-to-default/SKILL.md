---
name: merge-to-default
description: Use when the user wants to land the current branch on the project's default branch with a github-style merge commit. Triggers on /git-discipline:merge-to-default, "merge naar default", "merge to main", "merge this into main". Commits any pending work via commit-all-the-things first, produces a --no-ff merge commit, rebases the source branch on conflict before retrying, and deletes the local source branch after the merge is confirmed (remote branches are left to GitHub workflows).
allowed-tools: Bash(git symbolic-ref:*), Bash(git rev-parse:*), Bash(git status:*), Bash(git checkout:*), Bash(git merge:*), Bash(git rebase:*), Bash(git log:*), Bash(git diff:*), Bash(git ls-remote:*), Bash(git remote:*), Bash(git branch:*), Bash(git worktree:*), Skill(git-discipline:commit-all-the-things), Skill(git-discipline:rebase-latest-default)
---

# /git-discipline:merge-to-default

Land the current branch on the project's default branch with a real `--no-ff` merge commit, the same shape GitHub's merge button produces. Pending working-tree changes ride along via `git-discipline:commit-all-the-things`. On a conflict the source branch is rebased on the latest default and the merge is retried so the final state is a clean merge commit on top of an up-to-date default.

## When

- The current feature branch is done and needs to land on `main` (or `master`)
- The user types `/git-discipline:merge-to-default` or says "merge naar default", "merge to main", or "merge this into main"
- Local workflow without a PR step: the project does trunk-based development or accepts direct merges on the default branch

Not for remote merges: this skill produces only local commits and does not push. Push is a separate, explicit user action.

## Step 0: Detect default branch and current branch

### 0a: Default branch name

Determine the name of the default branch (`$DEFAULT`):

1. Try `git symbolic-ref refs/remotes/origin/HEAD` and take the last path segment (e.g. `main`).
2. If that fails (no remote, or the ref is not set), check locally: `git rev-parse --verify refs/heads/main` and `git rev-parse --verify refs/heads/master`. Prefer `main` if both exist.
3. If neither exists, stop with the message: `Cannot determine the default branch. Set origin/HEAD via `git remote set-head origin --auto` or create a local main/master.`

### 0b: Current branch

```bash
CURRENT=$(git symbolic-ref --short HEAD)
```

If `git symbolic-ref --short HEAD` fails (detached HEAD), stop with the message: `HEAD is detached. Switch to a branch before invoking /git-discipline:merge-to-default.`

## Step 1: No-op safeguard when already on default

If `$CURRENT` equals `$DEFAULT`, do nothing. Show a clear TUI warning and stop:

```
⚠  /git-discipline:merge-to-default is a no-op on the default branch itself.
    Current branch: <DEFAULT>
    There is nothing to merge into <DEFAULT> from <DEFAULT>.

    Switch to the feature branch you want to merge first, then re-run
    /git-discipline:merge-to-default. Run `git branch` to list local branches,
    or `git reflog` to find the branch you were on before HEAD landed
    here.
```

No commit, no merge, no rebase. Exit cleanly.

## Step 2: Commit pending work via commit-all-the-things

Run `git status --porcelain`. Not empty means there is uncommitted work on the feature branch that should ride along on the merge.

Invoke `git-discipline:commit-all-the-things` via the Skill tool. That sub-skill groups all uncommitted changes into logical commits according to the project- and user-CLAUDE.md conventions and commits them on the current branch (`$CURRENT`). Wait until that skill is done before continuing.

After the invocation: `git status --porcelain` is empty, otherwise stop with the message `commit-all-the-things left uncommitted changes; investigate before merging.`

**Important to know up front:** the skill commits EVERYTHING that is there, including half-finished work the user did not want to lock in yet. Anyone who has staged or working-tree changes that do not belong with the merge should set those aside first (`git stash push -m "wip"`, or a separate snipe commit on another branch) before invoking `/git-discipline:merge-to-default`. The skill has no opt-out for step 2; that is deliberate, because a half-merge with unspoken pending changes muddies the history.

## Step 3: First-pass merge

First save the tip of the source branch, then checkout and merge:

```bash
PRE_MERGE_TIP=$(git rev-parse "$CURRENT")
git checkout $DEFAULT
git merge --no-ff --no-edit $CURRENT
```

`PRE_MERGE_TIP` is used later in Step 5 to confirm that the merge actually integrated the source tip, independent of what some other process (e.g. another shell) does to the `$CURRENT` ref in the meantime.

`--no-ff` forces a merge commit (two parents), even when the default branch sits exactly behind the feature branch. This gives the history the same shape that GitHub's "Create a merge commit" button produces; the iteration on the feature branch stays visible in `git log --graph`. A fast-forward or squash merge would flatten that same iteration, which is why `--no-ff` is non-negotiable here. Anyone who prefers a fast-forward or a rebase merge can use `git merge --ff-only` or `git rebase` directly from the command line; this skill is specifically for the github-merge-button shape.

`--no-edit` keeps the auto-generated merge subject (`Merge branch '<CURRENT>'`), the same shape GitHub uses for a local merge. That is deliberately not the PR-merge subject (`Merge pull request #N from ...`), because this skill does not create a PR and does not know a PR number.

- **Succeeds cleanly:** continue to Step 5.
- **Conflicts:** continue to Step 4.

## Step 4: Conflict path via rebase

When the merge in step 3 produces conflicts, the source branch is behind on the default or the same piece of code was changed on both sides. The skill ALWAYS chooses `rebase first, retry merge` here over manual conflict resolution in a merge commit, because the resulting history then shows a clean merge commit on top of an up-to-date default.

```bash
git merge --abort
git checkout $CURRENT
```

Invoke `git-discipline:rebase-latest-default` via the Skill tool. That sub-skill rebases `$CURRENT` on the freshest `$DEFAULT` (local or `origin/$DEFAULT`, whichever is ahead) and resolves trivial conflicts (whitespace, identical edits, lockfile regenerations) automatically. For genuine ambiguities, rebase-latest-default stops and surfaces them to the user.

After a successful rebase: capture the new source tip before the retry checkout, then back to Step 3 for the retry.

```bash
PRE_MERGE_TIP=$(git rev-parse "$CURRENT")
git checkout $DEFAULT
git merge --no-ff --no-edit $CURRENT
```

The merge should run cleanly now. If it still fails, surface the conflict and stop; that means the rebase could not resolve all ambiguity and the user must intervene manually.

### When rebase-latest-default itself stops on a non-trivial conflict

`git-discipline:rebase-latest-default` only resolves trivial conflicts (whitespace, identical edits, lockfile regenerations) automatically. For genuine ambiguity, that skill stops mid-rebase and points the user at the conflicting files. In that case `merge-to-default` has also stopped: the worktree sits mid-rebase on `$CURRENT`, `$DEFAULT` is unchanged. The user has three cleanup options:

- `git rebase --abort`: returns `$CURRENT` to the pre-rebase state. No merge happened. After that, the user can tackle the conflict differently.
- Manually resolve the conflict, `git rebase --continue` per step, and then invoke `/git-discipline:merge-to-default` again to run the retry merge.
- `git checkout $DEFAULT` without further action: the mid-rebase state on `$CURRENT` remains, `$DEFAULT` is intact, the user decides later what to do.

`merge-to-default` itself does not make any of these choices for the user; mid-rebase with genuine ambiguity is exactly the place where manual resolution is the right way.

## Step 5: Clean up local source branch

After a confirmed merge, the skill cleans up the local `$CURRENT` branch. Confirmed means: HEAD sits on `$DEFAULT`, HEAD has two parents, and the second parent matches `PRE_MERGE_TIP` (from Step 3) or, in the rebase path, the tip `$CURRENT` had right before the retry merge in Step 4. The skill checks that with:

```bash
SECOND_PARENT=$(git rev-parse HEAD^2 2>/dev/null || true)
[ "$SECOND_PARENT" = "$PRE_MERGE_TIP" ] || stop_with "merge confirmation failed; HEAD^2 ($SECOND_PARENT) does not match captured pre-merge source tip ($PRE_MERGE_TIP)"
```

In the rebase path, Step 4 repeats the `PRE_MERGE_TIP=$(git rev-parse "$CURRENT")` capture after the rebase and before the retry checkout, so the confirmation check compares against the post-rebase tip. By recording `PRE_MERGE_TIP` before the checkout, the skill closes a race window: a concurrent commit on `$CURRENT` after the checkout can shift the live `git rev-parse "$CURRENT"`, but `PRE_MERGE_TIP` stays at the value the merge actually integrated.

When that holds: try to delete the branch with `git branch -d "$CURRENT"`. Before that command, the skill checks two things:

1. **Worktree safety.** `git worktree list --porcelain` shows one block per worktree with `worktree <path>` and `branch refs/heads/<name>`. The current worktree root comes from `git rev-parse --show-toplevel` (NOT `--git-dir`, which gives the `.git` directory and never matches the `worktree` field). When some other block has `branch refs/heads/$CURRENT`, skip the delete and surface a TUI line: `⚠  Source branch '<CURRENT>' is checked out in worktree <path>; skipping local branch delete.` The merge commit on `$DEFAULT` stays intact, only the local ref of `$CURRENT` remains.

2. **No `-D` force.** The skill uses `-d` (lowercase), not `-D`. `-d` fails on un-merged branches; in this flow `$CURRENT` is by definition merged into `$DEFAULT` via the merge commit, so `-d` succeeds. If `-d` does fail (race condition with user input between step 3/4 and step 5), surface the error and stop without forcing.

This skill does not touch remote branches. The assumption is that GitHub workflows (branch protection rules with "delete head branch on merge") or a separate cleanup job clean up the remote `origin/<CURRENT>` when the PR merge lands upstream. If your repo does not do that, clean up the remote branch yourself with `git push origin --delete <CURRENT>` after the push (which is not part of this skill).

## Step 6: Reporting

Show a brief summary of what happened:

```
✓ Merged <CURRENT> into <DEFAULT>
  Merge commit: <abbrev SHA>
  Files changed: <N>, +<INS> -<DEL>
  Rebase preceded merge: yes/no
  Local source branch: deleted | kept (worktree at <path>)
```

`<abbrev SHA>` comes from `git rev-parse --short HEAD`. `Files changed`, insertions, and deletions come from `git diff --shortstat $DEFAULT~1...$DEFAULT`. The `Local source branch` line reflects what Step 5 did: `deleted` if `git branch -d` succeeded, `kept (worktree at <path>)` if the safety check skipped the delete, or `kept (delete failed: <reason>)` if `-d` failed for another reason.

Push does NOT happen in this skill. A push to the remote is a separate user-go (the user-CLAUDE.md push regime documents this). The user pushes themselves once they have validated the merge is correct.
