#!/usr/bin/env bash
# Shared helpers for the cross-layer integration BATS suite.
#
# These tests verify that the PreToolUse string-parsing path and the
# file-input path (git-native commit-msg hook) produce equivalent verdicts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../../hooks/lib/validate-body.sh"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
export GIT_SHIM_DIFF_CACHED_OUTPUT=""
export GIT_SHIM_LOG_HASHES=""
export GIT_SHIM_LOG_BODY=""
export GIT_SHIM_HEAD_ABBREV="feature/cross-layer"
export GIT_SHIM_HEAD_SHORT="deadbeef"
export GIT_SHIM_SHORTSTAT=" 3 files changed, 25 insertions(+)"
export GIT_SHIM_DIFF_NAMES="$(printf 'app/services/session.rb\napp/models/user.rb\nspec/services/session_spec.rb')"
export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/somerepo.git"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  export TMPDIR_TEST

  local shim_bin="$TMPDIR_TEST/bin"
  mkdir -p "$shim_bin"

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
REAL_GIT=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
args=("$@")

if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  if [[ -n "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT" ]]; then
    printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"
    exit 0
  fi
  # Fall through to real git when shim output not set.
  [[ -n "$REAL_GIT" ]] && exec "$REAL_GIT" "$@"
  exit 0
fi

if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s\n' "$GIT_SHIM_LS_TREE_OUTPUT"
  exit 0
fi

if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--cached" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_CACHED_OUTPUT"
  exit 0
fi

if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then
  printf '%s\n' "$GIT_SHIM_SHORTSTAT"
  exit 0
fi

if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"
  exit 0
fi

if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then
  [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
  exit 0
fi

if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then
  printf '%s\n' "$GIT_SHIM_LOG_BODY"
  exit 0
fi

if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"
  exit 0
fi

if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_SHORT"
  exit 0
fi

if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then
  printf 'deadbeef00000000\n'
  exit 0
fi

# git rev-parse --show-toplevel
# Sandboxed to TMPDIR_TEST (or BATS_TEST_TMPDIR) so the validator's
# Visual: path-resolution does not escape the per-test tempdir.
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--show-toplevel" ]]; then
  printf '%s\n' "${TMPDIR_TEST:-${BATS_TEST_TMPDIR:-/}}"
  exit 0
fi

if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then
  printf '%s\n' "$GIT_SHIM_ORIGIN_URL"
  exit 0
fi

[[ -n "$REAL_GIT" ]] && exec "$REAL_GIT" "$@"
printf 'git shim: unhandled args: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"
  export PATH="$shim_bin:$PATH"

  # Silence commit-subject rotation state.
  local _state_file="$TMPDIR_TEST/commit-rule-state"
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"
  export GIT_DISCIPLINE_SHADOW_LOG="$TMPDIR_TEST/shadow.log"

  GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  GIT_SHIM_DIFF_CACHED_OUTPUT=""
  GIT_SHIM_LOG_HASHES=""
  GIT_SHIM_LOG_BODY=""
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# write_fixture <filename> <content>
write_fixture() {
  local name="$1"
  local content="$2"
  printf '%s' "$content" > "$TMPDIR_TEST/$name"
  printf '%s' "$TMPDIR_TEST/$name"
}

# invoke_validator_file <fixture-file>
# Calls validate_body directly on a file; merges stderr into stdout.
invoke_validator_file() {
  local file="$1"
  bash -c "source '$VALIDATOR'; validate_body '$file'" 2>&1
}

# pretool_bash_json <bash-command-string>
pretool_bash_json() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch <bash-command-string>
run_dispatch_cmd() {
  local cmd="$1"
  local json
  json=$(pretool_bash_json "$cmd")
  bash "$DISPATCH" <<< "$json" 2>&1
  printf '%d' "$?"
}
