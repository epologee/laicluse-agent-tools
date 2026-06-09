#!/usr/bin/env bash
# Shared setup for the repo-deny BATS suite.
#
# Strategy: create a real git repo inside BATS_TEST_TMPDIR so
# `git rev-parse --git-common-dir` returns a real path that the guard can
# inspect. Override $HOME so any sentinel writes by other guards land in
# the temp directory rather than the operator's real home.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  cd "$BATS_TEST_TMPDIR"
  git init -q
  git -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "init"
}

teardown() {
  : # BATS cleans BATS_TEST_TMPDIR.
}

# pretool_bash_json <bash-command>
pretool_bash_json() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch <bash-command>
run_dispatch() {
  local cmd="$1"
  local json
  json=$(pretool_bash_json "$cmd")
  run bash "$DISPATCH" <<< "$json"
}

# write_sentinel [reason]
write_sentinel() {
  local reason="${1:-}"
  if [[ -n "$reason" ]]; then
    printf '%s\n' "$reason" > "$BATS_TEST_TMPDIR/.git/git-discipline-deny"
  else
    : > "$BATS_TEST_TMPDIR/.git/git-discipline-deny"
  fi
}
