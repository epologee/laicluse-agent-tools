#!/usr/bin/env bats
# allow-comment: PostToolUse for commit-subject implements the +1 shift: after a confirmed commit (HEAD moved since ack_pending_sha), the dispatcher advances rp, sets pr to the next rotation slot, and emits a non-blocking nudge naming the rule the next commit needs to ack. The bootstrap deny still owns the first commit per fresh state.

load helpers

read_rp() { read_state_field "$1" rp; }
read_pr() { read_state_field "$1" pr; }
read_pending_sha() { read_state_field "$1" ack_pending_sha; }

@test "PostToolUse with HEAD moved advances rp, sets pr to next slot, emits hint" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf 'pv=-1\npr=-1\nrp=0\nack_pending_sha=feedfacefeedface\n' > "$state"

  run_posttool_dispatch "git commit -m 'Boundary on read path'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"[git-discipline/commit-subject]"* ]]
  [[ "$output" == *"ack-rule"* ]]
  [[ "$output" == *"Next-commit rotation reminder"* ]]

  [ "$(read_rp "$state")" = "1" ]
  [ -z "$(read_pending_sha "$state")" ]
  [ "$(read_pr "$state")" != "-1" ]
}

@test "PostToolUse with HEAD unchanged does not advance and emits nothing" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf 'pv=-1\npr=3\nrp=0\nack_pending_sha=deadbeef00000000\n' > "$state"

  run_posttool_dispatch "git commit -m 'Boundary on read path'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"additionalContext"* ]]

  [ "$(read_rp "$state")" = "0" ]
  [ "$(read_pr "$state")" = "3" ]
  [ "$(read_pending_sha "$state")" = "deadbeef00000000" ]
}

@test "PostToolUse with no ack_pending_sha is silent no-op" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf 'pv=-1\npr=-1\nrp=2\nack_pending_sha=\n' > "$state"

  run_posttool_dispatch "git commit -m 'Boundary on read path'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"additionalContext"* ]]

  [ "$(read_rp "$state")" = "2" ]
  [ "$(read_pr "$state")" = "-1" ]
}

@test "PostToolUse on non-commit Bash command is a no-op" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf 'pv=-1\npr=-1\nrp=0\nack_pending_sha=feedfacefeedface\n' > "$state"

  run_posttool_dispatch "git status"
  [ "$status" -eq 0 ]
  [[ "$output" != *"additionalContext"* ]]

  [ "$(read_rp "$state")" = "0" ]
  [ "$(read_pending_sha "$state")" = "feedfacefeedface" ]
}

@test "Full +1 shift cycle: PostToolUse pins next slot, next PreToolUse with right ack passes silently" {
  local state="$BATS_TEST_TMPDIR/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$state"
  printf 'pv=-1\npr=-1\nrp=0\nack_pending_sha=feedfacefeedface\n' > "$state"

  run_posttool_dispatch "git commit -m 'Boundary on read path'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Next-commit rotation reminder"* ]]

  local next_pr next_num password
  next_pr=$(read_pr "$state")
  [ "$next_pr" != "-1" ]
  next_num=$((next_pr + 1))
  case "$next_pr" in
    4) password="dubbelop" ;;
    5) password="proza" ;;
    6) password="atoom" ;;
    7) password="inferno" ;;
    8) password="solist" ;;
    9) password="incognito" ;;
    10) password="loep" ;;
    11) password="bewijsstuk" ;;
    12) password="kralen" ;;
    13) password="voorwaarts" ;;
    14) password="steiger" ;;
    *) password="" ;;
  esac
  [ -n "$password" ]

  run_dispatch "git commit -m 'Second boundary on read path' # ack-rule${next_num}:${password}"
  [ "$status" -eq 0 ]
}
