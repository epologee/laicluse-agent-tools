#!/bin/bash
# packages/git-discipline/hooks/lib/conflict-markers.sh
#
# Shared detection for leftover conflict markers in tracked files. Sourced by both
# the PreToolUse:Bash guard (hooks/guards/merge-conflict-markers.sh) and the
# git-native commit-msg hook, so the two enforcement paths cannot drift.
#
# Detection unions `git diff --check` (working tree vs index) and `--cached`
# (index vs HEAD): the first catches unstaged markers, the second catches a
# marker-bearing file that was `git add`-ed before committing (the case that broke
# a live checkout and prompted this guard). git's own checker fires only on real
# conflict regions, so a `=======` markdown underline does not match.
#
# Functions never exit; callers decide how to surface the verdict.
#   conflict_markers_find_files                          -> unique dirty files, one per line; empty = clean
#   conflict_markers_escape_active <bash-command-or-empty> -> 0 when an escape is active (see below)
#   conflict_markers_format_message <files-newline-list> -> human message naming the files + escapes

conflict_markers_find_files() {
  # `|| true`: grep exits 1 on the (common) no-marker case; without it the
  # pipeline's non-zero status would surface under a caller's set -o pipefail.
  { git diff --check; git diff --cached --check; } 2>/dev/null \
    | grep -F ': leftover conflict marker' \
    | sed -E 's/:[0-9]+: leftover conflict marker$//' \
    | LC_ALL=C sort -u \
    || true
}

conflict_markers_escape_active() {
  local command="${1:-}"
  if [[ "${GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS:-0}" = "1" ]]; then
    return 0
  fi
  if [[ -n "$command" ]] && grep -qF '# allow-conflict-markers' <<< "$command"; then
    return 0
  fi
  return 1
}

conflict_markers_format_message() {
  local files="$1"
  local out=""
  out+=$'conflict resolution incomplete: conflict markers remain in tracked files:\n'
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    out+="  ${f}"$'\n'
  done <<< "$files"
  out+=$'\nResolve every conflict region (the <<<<<<< / ======= / >>>>>>> lines) before\n'
  out+=$'finalizing the merge so a half-resolved merge cannot land in a live checkout.\n'
  out+=$'Escapes (rare, e.g. a deliberate fixture):\n'
  out+=$'  export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1   (any commit: terminal or Claude)\n'
  out+=$'  append  # allow-conflict-markers  to the command (only when Claude runs it)\n'
  printf '%s' "$out"
}
