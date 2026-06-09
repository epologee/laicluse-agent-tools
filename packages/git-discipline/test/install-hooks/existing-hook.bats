#!/usr/bin/env bats
# existing-hook.bats
# When commit-msg already exists with different content:
#   - without --force: print diff, refuse, exit 1.
#   - with --force: backup as <hook>.bak.<timestamp>, overwrite.

load helpers

setup_existing_commit_msg() {
  install -d "$TEST_REPO/.git/hooks"
  cat > "$TEST_REPO/.git/hooks/commit-msg" <<'OLD'
#!/bin/sh
# Pre-existing commit-msg hook from another tool.
exit 0
OLD
  chmod +x "$TEST_REPO/.git/hooks/commit-msg"
}

@test "without --force, refuses to overwrite and prints diff" {
  setup_existing_commit_msg

  run_install "$TEST_REPO"

  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists with different content"* ]]
  [[ "$output" == *"Refusing to overwrite"* ]]
  # Existing content is unchanged.
  grep -q 'Pre-existing commit-msg hook' "$(hook_target_path commit-msg)"
}

@test "with --force, creates a backup and overwrites" {
  setup_existing_commit_msg

  run_install "$TEST_REPO" --force

  [ "$status" -eq 0 ]
  # Backup file exists with the .bak. prefix.
  ls "$TEST_REPO/.git/hooks/" | grep -q '^commit-msg\.bak\.'
  # New content is in place (no longer the pre-existing one).
  ! grep -q 'Pre-existing commit-msg hook' "$(hook_target_path commit-msg)"
  grep -q 'git-discipline/commit-msg' "$(hook_target_path commit-msg)"
}

@test "without --force, post-commit still installs (per-hook conflict isolation)" {
  setup_existing_commit_msg

  run_install "$TEST_REPO"

  # commit-msg conflict caused exit 1, but post-commit had no conflict and
  # should still have landed.
  [ "$status" -eq 1 ]
  [ -f "$(hook_target_path post-commit)" ]
}
