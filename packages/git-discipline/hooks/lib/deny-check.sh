#!/bin/bash
# packages/git-discipline/hooks/lib/deny-check.sh
# Shared deny-check helper for the git-native CLI hooks (commit-msg,
# pre-push). Mirrors the PreToolUse:Bash guard at hooks/guards/repo-deny.sh
# so the verdict is identical regardless of which path fires first.
#
# Sourced by hooks; never executed directly. Callers invoke
# `deny_check <action>` where <action> is the user-visible verb in the deny
# message ("commit", "push", ...). The function exits 1 when the per-repo
# sentinel is present so the calling hook never returns to its main flow.

deny_check() {
  local action="${1:-operation}"
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null || true)
  if [[ -z "$common_dir" || ! -f "$common_dir/git-discipline-deny" ]]; then
    return 0
  fi

  local reason
  reason=$(head -n1 "$common_dir/git-discipline-deny" 2>/dev/null || true)
  local reason_part=""
  [[ -n "$reason" ]] && reason_part=" Reason: $reason."

  printf '[git-discipline/disable-git] %s blocked by %s/git-discipline-deny.%s Run /git-discipline:enable-git to lift.\n' \
    "$action" "$common_dir" "$reason_part" >&2
  exit 1
}
