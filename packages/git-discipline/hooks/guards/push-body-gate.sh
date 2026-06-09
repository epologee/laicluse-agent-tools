#!/bin/bash
# allow-comment: PreToolUse:Bash safety net that validates every commit body in the push range against validate_body and denies the push when one or more commits fall short. The companion to PostToolUse commit-body: PostToolUse stays silent during local iteration, push-body-gate is the loud final gate before commits leave the machine.

guard_push_body_gate() {
  local input="$1"

  [[ "${GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED:-0}" = "1" ]] && return 0

  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  dd_is_git_push_command "$command" || return 0

  local DIR
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "$DIR/lib/wip-gate.sh"

  local range
  range=$(wip_gate_resolve_push_range "$command")

  [[ -z "$range" ]] && return 0

  local commits
  commits=$(git rev-list "$range" 2>/dev/null || true)
  [[ -z "$commits" ]] && return 0

  local me
  me=$(git config user.email 2>/dev/null || true)

  local violations=()
  local sha message subject tmpfile output rc shortstat file_count insertion_count
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue

    # allow-comment: personal discipline only judges commits that are ours
    # allow-comment: (authored or rebase-co-authored); purely-carried teammate
    # allow-comment: commits swept in by a rebase are never demanded a body.
    wip_gate_commit_is_ours "$sha" "$me" || continue

    message=$(git log -1 --pretty=format:%B "$sha" 2>/dev/null || true)
    [[ -z "$message" ]] && continue

    subject=$(printf '%s' "$message" | head -1)
    if validate_body_classify_skip "$subject"; then
      continue
    fi

    shortstat=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$sha" _vb_delta_shortstat)
    file_count=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$sha" _vb_delta_files | grep -c . | tr -d ' ')
    insertion_count=0
    if [[ "$shortstat" =~ ([0-9]+)[[:space:]]+insertion ]]; then
      insertion_count="${BASH_REMATCH[1]}"
    fi
    # allow-comment: trivial-ok travels as an inline env-var on the validator
    # allow-comment: call rather than an exported global; no per-iteration
    # allow-comment: cleanup needed because the scope ends with the $() subshell.
    local trivial_ok=0
    if [[ "$file_count" -le 1 && "$insertion_count" -le 5 ]]; then
      trivial_ok=1
    fi

    tmpfile=$(mktemp /tmp/git-discipline-push-body-XXXXXX)
    printf '%s' "$message" > "$tmpfile"
    output=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$sha" GIT_DISCIPLINE_TRIVIAL_OK="$trivial_ok" validate_body "$tmpfile" 2>&1)
    rc=$?
    rm -f "$tmpfile"

    if [[ "$rc" -eq 1 ]]; then
      local short_sha line
      short_sha=$(git rev-parse --short "$sha" 2>/dev/null || printf '%s' "${sha:0:7}")
      line=$(printf '%s' "$output" | head -1)
      violations+=("${short_sha} \"${subject}\": ${line}")
    fi
  done <<< "$commits"

  [[ ${#violations[@]} -eq 0 ]] && return 0

  local msg
  msg=$(printf 'Body schema misses in push range:\n')
  local v
  for v in "${violations[@]}"; do
    msg+=$(printf -- '\n  %s' "$v")
  done
  msg+=$(printf '\n\nAmend or interactive-rebase each commit to fix, then retry push. For commits whose bodies predate the discipline and were rewritten by a rebase, amend the trailer "Discipline: skip due to rebase" onto them instead of reworking the body; the gate treats those as already-shipped. Use /git-discipline:disable-discipline if you need to lift the discipline for this session.')

  dd_emit_deny "push-body-gate" "$msg"
}
