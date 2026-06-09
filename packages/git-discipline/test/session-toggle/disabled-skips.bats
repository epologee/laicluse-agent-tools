#!/usr/bin/env bats
# packages/git-discipline/test/session-toggle/disabled-skips.bats
#
# When the session sentinel exists, dispatch.sh exits 0 silently before
# invoking any guard. The guards that would otherwise fire on a bad commit
# must not produce output or a non-zero exit code.

load helpers

@test "sentinel present: dispatch exits 0 for a commit that would normally be blocked" {
  local sid="test-session-abc123"
  write_session_sentinel "$sid"

  # A bare subject with no body would normally be blocked by commit-body.
  run_dispatch_with_session \
    'git commit -m "bad commit no body" # ack-rule4:essentie' \
    "$sid"

  [ "$status" -eq 0 ]
}

@test "sentinel present: no guard output is produced" {
  local sid="test-session-abc123"
  write_session_sentinel "$sid"

  run_dispatch_with_session \
    'git commit -m "bad commit no body" # ack-rule4:essentie' \
    "$sid"

  [[ "$output" != *"[git-discipline/"* ]]
}

@test "sentinel present: a git push that would hit wip-gate also exits 0 silently" {
  local sid="test-session-wip99"
  write_session_sentinel "$sid"

  run_dispatch_with_session \
    'git push origin feature/wip-branch' \
    "$sid"

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/"* ]]
}

@test "sentinel for a DIFFERENT session does not suppress guards" {
  local active_sid="test-session-active"
  local other_sid="test-session-other"
  write_session_sentinel "$other_sid"

  # Commit missing body: guards should fire for the active (unsuppressed) session.
  # The command uses a subject with no valid body; the shim is set to a
  # non-trivial diff so that commit-body actually checks.
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/foo.rb\napp/models/bar.rb\nspec/models/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch_with_session \
    'git commit -m "bare subject no body" # ack-rule4:essentie' \
    "$active_sid"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/commit-body]"* ]]
}
