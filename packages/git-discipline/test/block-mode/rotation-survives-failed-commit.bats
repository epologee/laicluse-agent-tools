#!/usr/bin/env bats
# rotation-survives-failed-commit.bats
# When a commit passes the rotation reminder (ack accepted) but never lands
# (HEAD does not move because a later gate or git itself rejected it), the
# operator's ack must still count on the retry. The retry should pass phase-2
# directly, not drop back to a fresh phase-1 reminder that costs a second
# round-trip for an ack already given.

load helpers

@test "an accepted ack survives a commit that did not land" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/foo.rb\nspec/controllers/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$VALID_TRAILERS"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/controllers/foo_spec.rb"

  local cmd
  cmd=$(commit_cmd_heredoc "Controller boundary for incoming session events" \
    "$(printf 'When StartTransaction messages arrive with an invalid meter reading,\nthe previous implementation rejected the entire event.')")
  cmd="$cmd # ack-rule4:essentie"

  # First attempt: ack accepted, commit allowed to proceed (exit 0).
  run_dispatch "$cmd"
  [ "$status" -eq 0 ]

  # The commit did not land: the shim's HEAD is unchanged. The same ack on the
  # retry must still pass phase-2, not re-serve a phase-1 reminder (exit 2).
  run_dispatch "$cmd"
  [ "$status" -eq 0 ]
}
