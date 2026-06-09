#!/usr/bin/env bats
# Rotation advances only on confirmed commit success, not on PreToolUse
# pass. The guard records the HEAD sha at ack-match; the next dispatcher
# entry advances rp when HEAD has moved (commit landed) and leaves rp
# alone when HEAD is unchanged (commit failed at commit-msg / pre-commit
# / never ran).

load helpers

setup_pending_ack_state() {
  local state_file="$1" pending_sha="$2"
  printf 'pv=-1\npr=-1\nrp=5\nack_pending_sha=%s\n' "$pending_sha" > "$state_file"
}

read_rp() {
  read_state_field "$1" rp
}

read_pending_sha() {
  read_state_field "$1" ack_pending_sha
}

@test "HEAD advanced since ack: rp advances and pending sha clears" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Shim returns deadbeef00000000 for HEAD; pretend the previous ack was
  # against a different sha so the guard sees HEAD has moved.
  setup_pending_ack_state "$state" "feedfacefeedface"

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  # rp was 5; HEAD moved -> advance to 6.
  [ "$(read_rp "$state")" = "6" ]
  [ -z "$(read_pending_sha "$state")" ]
}

@test "HEAD unchanged since ack: rp stays and pending sha clears" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Pretend the previous ack was against the same sha the shim now reports.
  setup_pending_ack_state "$state" "deadbeef00000000"

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  # rp was 5; HEAD did not move -> stays at 5. After this run pending sha
  # is cleared (single-shot resolution), and the deny-flow then writes a
  # new pending rotation. So we assert rp first, before the guard's own
  # rotation-pending write.
  local rp_after pending_after
  rp_after=$(read_rp "$state")
  pending_after=$(read_pending_sha "$state")
  [ "$rp_after" = "5" ]
  [ -z "$pending_after" ]
}

@test "ack match writes HEAD sha to pending field, rp unchanged" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Pre-set pending rotation = rule 11 (idx 10), rp arbitrary.
  printf 'pv=-1\npr=10\nrp=7\nack_pending_sha=\n' > "$state"

  run_dispatch "git commit -m 'Capture HEAD sha when ack matches' # ack-rule11:loep"
  [ "$status" -eq 0 ] || {
    printf 'expected dispatch to pass, got status %s, output: %s\n' "$status" "$output" >&2
    return 1
  }

  # rp must NOT have advanced; pending sha must equal the shim HEAD.
  [ "$(read_rp "$state")" = "7" ]
  [ "$(read_pending_sha "$state")" = "deadbeef00000000" ]
}
