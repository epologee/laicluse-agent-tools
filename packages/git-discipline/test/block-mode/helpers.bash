#!/usr/bin/env bash
# Shared setup, teardown, and fixture helpers for the block-mode BATS suite.
#
# Mock strategy: identical git-shim approach as shadow-mode/helpers.bash.
# The guard is tested by invoking dispatch.sh with synthetic PreToolUse JSON.
# In block-mode dispatch exits 2 on violation (dd_emit_deny) and 0 on pass.
#
# Shim variables:
#   GIT_SHIM_ORIGIN_URL   - what "git config --get remote.origin.url" returns
#   GIT_SHIM_SHORTSTAT    - what "git diff --cached --shortstat" returns
#   GIT_SHIM_DIFF_NAMES   - what "git diff --cached --name-only" returns
#   GIT_SHIM_HEAD_ABBREV  - what "git rev-parse --abbrev-ref HEAD" returns
#   GIT_SHIM_HEAD_SHORT   - what "git rev-parse --short HEAD" returns
#   (validate-body shim vars also available for inner validate calls)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

# Override shadow log so tests never write to the real log.
export GIT_DISCIPLINE_SHADOW_LOG="$BATS_TEST_TMPDIR/shadow.log"

# Shim defaults (can be overridden per test).
export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/somerepo.git"
export GIT_SHIM_SHORTSTAT=" 5 files changed, 30 insertions(+), 2 deletions(-)"
export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/foo.rb\napp/services/bar.rb\nspec/controllers/foo_spec.rb\nspec/services/bar_spec.rb\nconfig/routes.rb')"
export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
export GIT_SHIM_LS_TREE_OUTPUT="spec/controllers/foo_spec.rb"
export GIT_SHIM_DIFF_CACHED_OUTPUT=""
export GIT_SHIM_LOG_HASHES=""
export GIT_SHIM_LOG_BODY=""
export GIT_SHIM_HEAD_ABBREV="feature/block-mode"
export GIT_SHIM_HEAD_SHORT="deadbeef"

setup() {
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin" 2>/dev/null || true

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
# Git shim for block-mode BATS tests.
args=("$@")

# git config --get remote.origin.url
if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then
  printf '%s\n' "$GIT_SHIM_ORIGIN_URL"
  exit 0
fi

# git diff --cached --shortstat
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then
  printf '%s\n' "$GIT_SHIM_SHORTSTAT"
  exit 0
fi

# git diff --cached --name-only
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"
  exit 0
fi

# git interpret-trailers --parse
if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"
  exit 0
fi

# git ls-tree -r HEAD --name-only
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"
  exit 0
fi

# git log -5 --pretty=format:'%H' HEAD
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then
  [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
  exit 0
fi

# git log -1 --pretty=format:'%B' <hash>
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then
  printf '%s\n' "$GIT_SHIM_LOG_BODY"
  exit 0
fi

# git rev-parse --abbrev-ref HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"
  exit 0
fi

# git rev-parse --short HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_SHORT"
  exit 0
fi

# git rev-parse HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then
  printf 'deadbeef00000000\n'
  exit 0
fi

# git rev-parse --show-toplevel
# Sandbox the validator's Visual: path-resolution lookup so it does not
# escape the per-test tempdir. Falling through to real git would resolve
# to the surrounding repo root, mismatching any fixture file we wrote in
# BATS_TEST_TMPDIR.
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--show-toplevel" ]]; then
  printf '%s\n' "${BATS_TEST_TMPDIR:-/}"
  exit 0
fi

REAL_GIT=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
if [[ -n "$REAL_GIT" ]]; then
  exec "$REAL_GIT" "$@"
fi

printf 'git shim: unhandled: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"

  export PATH="$shim_bin:$PATH"

  # Pre-seed commit-subject rotation state so ack-rule4 passes immediately.
  local _state_file="$BATS_TEST_TMPDIR/commit-rule-state"
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"
}

teardown() {
  : # BATS_TEST_TMPDIR cleaned up by bats-core.
}

# ---------------------------------------------------------------------------
# Input builder helpers
# ---------------------------------------------------------------------------

# pretool_bash_json <bash-command-string>
pretool_bash_json() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch <bash-command-string>
run_dispatch() {
  local cmd="$1"
  local json
  json=$(pretool_bash_json "$cmd")
  run bash "$DISPATCH" <<< "$json"
}

# commit_cmd_simple <subject>
commit_cmd_simple() {
  printf 'git commit -m "%s"' "$1"
}

# commit_cmd_heredoc <subject> <body>
commit_cmd_heredoc() {
  local subject="$1"
  local body="$2"
  printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\n%s\n\n%s\nEOF\n)"' "$subject" "$body"
}

# shadow_log_line_count
shadow_log_line_count() {
  if [[ ! -f "$GIT_DISCIPLINE_SHADOW_LOG" ]]; then
    printf '0'
    return
  fi
  wc -l < "$GIT_DISCIPLINE_SHADOW_LOG" | tr -d ' '
}

# ---------------------------------------------------------------------------
# Standard valid-body trailer set (shimmed via GIT_SHIM_INTERPRET_TRAILERS_OUTPUT)
# ---------------------------------------------------------------------------

VALID_TRAILERS="$(printf 'Tests: spec/controllers/foo_spec.rb\nSlice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

VALID_BODY="$(cat <<'BODY'
Add controller boundary for incoming session events

When StartTransaction messages arrive with an invalid meter reading,
the previous implementation rejected the entire event and masked
session starts in the analytics pipeline.

Tests: spec/controllers/foo_spec.rb
Slice: handler + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
BODY
)"
