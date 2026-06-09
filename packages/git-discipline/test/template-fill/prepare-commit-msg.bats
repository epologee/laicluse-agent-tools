#!/usr/bin/env bats
# prepare-commit-msg.bats
# Unit tests for the prepare-commit-msg git hook.
#
# Strategy: render the hook by substituting __PLUGIN_INSTALL_PATH__ with the
# repo's packages/git-discipline path (development checkout), then invoke it directly
# against a temp msg-file with a git shim that controls staged paths.

load helpers

setup() {
  # Build a rendered copy of the hook with the placeholder resolved.
  local plugin_root="$REPO_ROOT/packages/git-discipline"
  RENDERED_HOOK="$BATS_TEST_TMPDIR/prepare-commit-msg"
  sed "s|__PLUGIN_INSTALL_PATH__|$plugin_root|g" \
    "$PREPARE_HOOK" > "$RENDERED_HOOK"
  chmod +x "$RENDERED_HOOK"

  # Build a git shim so the hook's "git diff --cached --name-only" call
  # returns what the test controls via GIT_SHIM_DIFF_NAMES.
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin"
  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
if [[ "$1" == "diff" && "$*" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"
  exit 0
fi
REAL=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
[[ -n "$REAL" ]] && exec "$REAL" "$@"
printf 'git shim: unhandled: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"
  export PATH="$shim_bin:$PATH"

  export GIT_SHIM_DIFF_NAMES="app/services/session.rb"$'\n'"spec/services/session_spec.rb"

  # Default msg-file: empty subject + git's standard comment block.
  MSG_FILE="$BATS_TEST_TMPDIR/COMMIT_EDITMSG"
  printf '\n# Please enter the commit message for your changes.\n# Lines starting with '"'"'#'"'"' will be ignored.\n' \
    > "$MSG_FILE"
}

teardown() {
  : # BATS_TEST_TMPDIR cleaned by bats-core.
}

# ---------------------------------------------------------------------------
# Normal interactive commit (empty source) -> template injected
# ---------------------------------------------------------------------------

@test "prepare-commit-msg: empty source injects template into msg-file" {
  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  # Fix 9: trailers are real lines now (not comment-only), so they survive git
  # comment-stripping and the validator can reject placeholder values.
  [[ "$content" == *"WHY:"* ]]
  [[ "$content" == *"Slice:"* ]]
  [[ "$content" == *"Tests:"* ]]
  [[ "$content" == *"Red-then-green:"* ]]
}

@test "prepare-commit-msg: trailer lines are real (not comment-prefixed)" {
  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  # The Slice and Tests trailer lines must NOT start with '#'. They must be
  # real lines so git does not strip them before the validator sees them.
  while IFS= read -r line; do
    if [[ "$line" =~ ^Slice: ]]; then
      # Found a real Slice line (no # prefix). Test passes.
      return 0
    fi
  done <<< "$content"
  # If we get here, no real (non-comment) Slice line was found.
  false
}

@test "prepare-commit-msg: empty source preserves git comment lines" {
  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  [[ "$content" == *"# Please enter the commit message"* ]]
}

@test "prepare-commit-msg: auto-detected layers appear in template" {
  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  # layer_summary for backend + spec should contain both tokens.
  [[ "$content" == *"Layers:"* ]]
  [[ "$content" == *"backend"* ]]
  [[ "$content" == *"spec"* ]]
}

@test "prepare-commit-msg: suggested Tests lists staged spec path" {
  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  [[ "$content" == *"session_spec.rb"* ]]
}

# ---------------------------------------------------------------------------
# Skip sources -> no template added
# ---------------------------------------------------------------------------

@test "prepare-commit-msg: merge source leaves msg-file unchanged" {
  original=$(cat "$MSG_FILE")
  bash "$RENDERED_HOOK" "$MSG_FILE" "merge"
  after=$(cat "$MSG_FILE")
  [ "$original" = "$after" ]
}

@test "prepare-commit-msg: squash source leaves msg-file unchanged" {
  original=$(cat "$MSG_FILE")
  bash "$RENDERED_HOOK" "$MSG_FILE" "squash"
  after=$(cat "$MSG_FILE")
  [ "$original" = "$after" ]
}

@test "prepare-commit-msg: message source leaves msg-file unchanged" {
  original=$(cat "$MSG_FILE")
  bash "$RENDERED_HOOK" "$MSG_FILE" "message"
  after=$(cat "$MSG_FILE")
  [ "$original" = "$after" ]
}

@test "prepare-commit-msg: commit (amend) source leaves msg-file unchanged" {
  original=$(cat "$MSG_FILE")
  bash "$RENDERED_HOOK" "$MSG_FILE" "commit" "deadbeef"
  after=$(cat "$MSG_FILE")
  [ "$original" = "$after" ]
}

@test "prepare-commit-msg: UI-touched diff includes Visual: line" {
  export GIT_SHIM_DIFF_NAMES="src/components/Banner.tsx"$'\n'"spec/banner_spec.rb"

  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  [[ "$content" == *"Visual:"* ]]
}

@test "prepare-commit-msg: backend-only diff does not include Visual: line" {
  export GIT_SHIM_DIFF_NAMES="app/services/billing.rb"$'\n'"spec/services/billing_spec.rb"

  bash "$RENDERED_HOOK" "$MSG_FILE" ""

  content=$(cat "$MSG_FILE")
  [[ "$content" != *"Visual:"* ]]
}

@test "prepare-commit-msg: template source leaves msg-file unchanged" {
  original=$(cat "$MSG_FILE")
  bash "$RENDERED_HOOK" "$MSG_FILE" "template"
  after=$(cat "$MSG_FILE")
  [ "$original" = "$after" ]
}
