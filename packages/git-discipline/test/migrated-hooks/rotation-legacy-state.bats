#!/usr/bin/env bats
# Backward-compat reads of the rotation state file. The reader handles
# the canonical key=value format and the two legacy positional formats
# (three-line: pv/pr/rp; four-line: pv/pr/rp/ack_pending_sha). The next
# write converges any legacy file to key=value.

load helpers

@test "legacy three-line state reads pv/pr/rp; pending sha defaults empty" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf '%s\n%s\n%s\n' '-1' '10' '7' > "$state"

  run_dispatch "git commit -m 'Capture HEAD sha when ack matches' # ack-rule11:loep"
  [ "$status" -eq 0 ] || {
    printf 'expected dispatch to pass on legacy three-line state, got status %s, output: %s\n' \
      "$status" "$output" >&2
    return 1
  }

  # ack matched; the writer converged to key=value, rp is preserved at 7,
  # pending sha is the shim HEAD.
  [ "$(read_state_field "$state" rp)" = "7" ]
  [ "$(read_state_field "$state" ack_pending_sha)" = "deadbeef00000000" ]
  grep -qE '^pv=' "$state"
  grep -qE '^pr=' "$state"
  grep -qE '^rp=' "$state"
  grep -qE '^ack_pending_sha=' "$state"
}

@test "legacy four-line positional state reads ack_pending_sha" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Previous-generation four-line positional file with a pending sha that
  # differs from the shim HEAD: the resolution branch must advance rp.
  printf '%s\n%s\n%s\n%s\n' '-1' '-1' '4' 'feedfacefeedface' > "$state"

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  # rp was 4; HEAD moved from feedface to deadbeef -> advance to 5.
  [ "$(read_state_field "$state" rp)" = "5" ]
  [ -z "$(read_state_field "$state" ack_pending_sha)" ]
  grep -qE '^pv=' "$state"
}

@test "writer emits key=value format" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf 'pv=-1\npr=-1\nrp=2\nack_pending_sha=\n' > "$state"

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  # The deny path triggered _dd_write_state with the new pending
  # rotation; the file must be in key=value form.
  [[ "$(head -1 "$state")" =~ ^pv= ]] || {
    printf 'expected first line to start with pv=, got: %s\n' "$(head -1 "$state")" >&2
    return 1
  }
}
