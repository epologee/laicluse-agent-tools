---
name: enable-git
user-invocable: true
description: >
  Lift the per-repo git lock set by /git-discipline:disable-git. Removes the sentinel
  file at .git/git-discipline-deny so Claude can run mutating git commands again.
disable-model-invocation: true
argument-hint: ""
---

# /git-discipline:enable-git

Remove the per-repo lock that `/git-discipline:disable-git` set. After this command
Claude is free to run mutating git commands again. Has no effect when no
sentinel is present.

## Implementation

Perform the following steps:

1. Resolve the git common dir:

   ```bash
   common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
   ```

   Bail with a clear error when not inside a git repo.

2. Remove the sentinel if it exists:

   ```bash
   sentinel="$common_dir/git-discipline-deny"
   if [[ -f "$sentinel" ]]; then
     rm "$sentinel"
     echo "git lock removed: $sentinel"
   else
     echo "no git lock was active for this repo"
   fi
   ```

3. Confirm to the operator which path was removed.

Do not write further explanation or caveats afterwards. The operator
typed this command deliberately.
