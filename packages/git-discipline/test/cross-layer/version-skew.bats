#!/usr/bin/env bats
# version-skew.bats
# Verifies that the commit-msg git-native hook reports a clear diagnostic
# when the baked plugin path no longer exists (plugin was updated/removed
# since the hook was installed).

load helpers

# ---------------------------------------------------------------------------
# Helper: write a commit-msg hook with a non-existent placeholder path.
# ---------------------------------------------------------------------------

_write_stale_hook() {
  local hook_file="$1"
  cat > "$hook_file" <<'HOOK'
#!/bin/bash
# Simulated stale commit-msg hook: __PLUGIN_INSTALL_PATH__ was not substituted
# or points to a path that no longer exists.

PLUGIN_PATH="/nonexistent/plugin/path/that/does/not/exist"
VALIDATOR="$PLUGIN_PATH/hooks/lib/validate-body.sh"

msg_file="${1:-}"

if [[ ! -f "$VALIDATOR" ]]; then
  printf 'git-discipline/commit-msg: validator not found at %s\n' "$VALIDATOR" >&2
  printf '  Re-run /git-discipline:install-hooks to refresh the plugin path, or\n' >&2
  printf '  use git commit --no-verify to bypass this check.\n' >&2
  exit 1
fi

exit 0
HOOK
  chmod +x "$hook_file"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "version-skew: hook with non-existent plugin path exits 1" {
  local hook="$TMPDIR_TEST/commit-msg-stale"
  _write_stale_hook "$hook"

  # Create a dummy commit-msg file to pass as $1.
  local msg_file="$TMPDIR_TEST/COMMIT_EDITMSG"
  printf 'Subject only\n' > "$msg_file"

  run bash "$hook" "$msg_file"
  [ "$status" -eq 1 ]
}

@test "version-skew: hook diagnostic mentions the missing path" {
  local hook="$TMPDIR_TEST/commit-msg-stale"
  _write_stale_hook "$hook"

  local msg_file="$TMPDIR_TEST/COMMIT_EDITMSG"
  printf 'Subject only\n' > "$msg_file"

  run bash "$hook" "$msg_file"
  [[ "$output" == *"/nonexistent/plugin/path"* ]]
}

@test "version-skew: hook diagnostic mentions install-hooks remedy" {
  local hook="$TMPDIR_TEST/commit-msg-stale"
  _write_stale_hook "$hook"

  local msg_file="$TMPDIR_TEST/COMMIT_EDITMSG"
  printf 'Subject only\n' > "$msg_file"

  run bash "$hook" "$msg_file"
  [[ "$output" == *"install-hooks"* ]]
}

@test "version-skew: hook with valid plugin path succeeds on trivial commit" {
  # Sanity check: a hook that resolves the real validator accepts a trivial commit.
  local plugin_root
  plugin_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  local hook="$TMPDIR_TEST/commit-msg-valid"
  sed "s|__PLUGIN_INSTALL_PATH__|${plugin_root}|g" \
    "$plugin_root/skills/commit-discipline/git-hooks/commit-msg" \
    > "$hook"
  chmod +x "$hook"

  # Single-file, 1-insertion staged diff -> trivial threshold.
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 1 insertion(+)"
  export GIT_SHIM_DIFF_NAMES="docs/README.md"

  # A git shim is already in PATH from setup().
  # Write a trace dir so the hook can write its trace without error.
  export HOME="$TMPDIR_TEST"

  local msg_file="$TMPDIR_TEST/COMMIT_EDITMSG"
  printf 'Tiny trivial change\n' > "$msg_file"

  run bash "$hook" "$msg_file"
  [ "$status" -eq 0 ]
}
