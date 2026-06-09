#!/usr/bin/env bats
# Empty repo / unreadable HEAD handling for the rotation. When
# `git rev-parse HEAD` returns nothing (no commits yet), the guard
# must let the initial commit through so a fresh `git init` repo can
# escape the Catch-22 (no commits without ack-resolution, no
# ack-resolution without HEAD). It writes "0" as the pending value:
# valid hex (survives the state-loader tr -cd '0-9a-f' strip), one
# char (cannot collide with a real 40-char sha), and visibly a
# sentinel on inspection. The next dispatcher pass compares the real
# HEAD sha against "0", detects a move, and advances the rotation. If
# the initial commit fails, HEAD stays absent and the symmetric
# empty-HEAD branch clears the pending without advancing.

load helpers

read_rp() { read_state_field "$1" rp; }
read_pending_sha() { read_state_field "$1" ack_pending_sha; }

@test "ack-match in an empty repo passes and seeds a sentinel pending sha" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Pending rotation = rule 11 (idx 10), pending sha empty.
  printf 'pv=-1\npr=10\nrp=7\nack_pending_sha=\n' > "$state"
  # Force the shim to mimic an empty repo for this run only.
  export GIT_SHIM_HEAD_SHA=""

  run_dispatch "git commit -m 'Capture HEAD sha when ack matches' # ack-rule11:loep"
  [ "$status" -eq 0 ] || {
    printf 'expected dispatch to pass on empty-repo ack, got status %s, output: %s\n' "$status" "$output" >&2
    return 1
  }

  # rp must NOT have advanced yet (commit has not landed); pending sha is
  # the sentinel so the next dispatcher pass resolves it against a real HEAD.
  [ "$(read_rp "$state")" = "7" ]
  [ "$(read_pending_sha "$state")" = "0" ]

  unset GIT_SHIM_HEAD_SHA
}

@test "resolution with empty HEAD clears pending sha without advancing rp" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Previous ack stored a pending sha; current shim returns empty for HEAD.
  printf 'pv=-1\npr=-1\nrp=5\nack_pending_sha=feedfacefeedface\n' > "$state"
  export GIT_SHIM_HEAD_SHA=""

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  # rp must NOT have advanced (no proof the commit landed); pending sha
  # is cleared (single-shot resolution semantics).
  [ "$(read_rp "$state")" = "5" ]
  [ -z "$(read_pending_sha "$state")" ]

  unset GIT_SHIM_HEAD_SHA
}

@test "sentinel pending sha resolves and advances rp once HEAD is non-empty" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  # Simulate: the previous PreToolUse pass on an empty repo wrote the
  # "0" sentinel. Now the initial commit has landed and HEAD has a real
  # sha (the shim default deadbeef00000000).
  printf 'pv=-1\npr=-1\nrp=5\nack_pending_sha=0\n' > "$state"

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  # rp was 5; sentinel != real HEAD -> advance to 6. Pending sha cleared.
  [ "$(read_rp "$state")" = "6" ]
  [ -z "$(read_pending_sha "$state")" ]
}
