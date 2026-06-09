#!/usr/bin/env bats
# packages/git-discipline/test/session-toggle/enabled-runs.bats
#
# When no sentinel exists for the session, dispatch.sh runs guards normally.
# A commit that violates the body schema must be blocked (exit 2). A commit
# that passes the schema must be allowed (exit 0).

load helpers

@test "no sentinel: non-trivial commit without body is nudged via additionalContext" {
  local sid="test-session-enabled"

  export GIT_SHIM_SHORTSTAT=" 3 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/foo.rb\napp/models/bar.rb\nspec/models/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch_with_session \
    'git commit -m "bare subject no body" # ack-rule4:essentie' \
    "$sid"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/commit-body]"* ]]
}

@test "no sentinel: trivial commit passes even without body" {
  local sid="test-session-enabled"
  # No sentinel written.

  # Default shim is 1 file, 1 insertion: trivial threshold, body guard is
  # skipped. The state file is pre-seeded with pv=-1, pr=3, rp=0. pr=3 means
  # a pending rotation reminder at slot value 3 (rule index 3 = ack-rule4).
  # The subject must not match the activity-word pattern (rule 1) or the
  # trigger-phrase pattern (rule 2). "Typo corrected in README" starts with
  # "Typo" which is not in the activity-word list; ack-rule4 clears pr=3.
  run_dispatch_with_session \
    'git commit -m "Typo corrected in README" # ack-rule4:essentie' \
    "$sid"

  [ "$status" -eq 0 ]
}

@test "no sentinel: git status passes without any guard output" {
  local sid="test-session-enabled"

  run_dispatch_with_session \
    'git status' \
    "$sid"

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/"* ]]
}
