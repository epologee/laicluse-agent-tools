#!/usr/bin/env bats
# amend-rotation-suppression.bats
# A gate-mandated `git commit --amend` of a just-acked commit does not burn
# a fresh rotation slot. Detection signal: HEAD's parent after the amend
# equals the previous HEAD's parent (amend keeps the same parent; a regular
# new commit makes the previous HEAD the parent of the new HEAD). The
# equal-parent rule also covers the root-commit amend: both parents are
# empty strings and compare equal, so the slot stays.

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  export TMPDIR_TEST
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

  cd "$TMPDIR_TEST" || return 1
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git config commit.gpgsign false 2>/dev/null || true

  STATE_FILE="$TMPDIR_TEST/commit-rule-state"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$STATE_FILE"
  export GIT_DISCIPLINE_SHADOW_LOG="$TMPDIR_TEST/shadow.log"
}

teardown() {
  cd /
  rm -rf "$TMPDIR_TEST"
}

# Pre-seed state to "rule 4 pending" so any ack-rule4 passes the
# pending-rotation branch deterministically.
seed_rotation_at_rule4() {
  printf 'pv=-1\npr=3\nrp=0\nack_pending_sha=\n' > "$STATE_FILE"
}

run_pretool() {
  local cmd="$1"
  local json
  json=$(jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')
  run bash "$DISPATCH" <<< "$json"
}

run_posttool() {
  local cmd="$1"
  local json
  json=$(jq -cn --arg c "$cmd" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c}}')
  run bash "$DISPATCH" <<< "$json"
}

read_rp() {
  grep '^rp=' "$STATE_FILE" | cut -d= -f2-
}

read_ack_pending_sha() {
  grep '^ack_pending_sha=' "$STATE_FILE" | cut -d= -f2-
}

# Simulate a full commit cycle: PreToolUse with ack, real git commit, PostToolUse.
# After: state reflects the landed commit (ack-pending-sha cleared, rp advanced or not).
land_commit() {
  local subject="$1"
  local file="$2"
  local content="$3"
  local amend="$4"   # "amend" or empty

  printf '%s\n' "$content" > "$file"
  git add "$file"

  local cmd
  if [[ "$amend" = "amend" ]]; then
    cmd="git commit --amend -m \"$subject\" # ack-rule4:essentie"
  else
    cmd="git commit -m \"$subject\" # ack-rule4:essentie"
  fi

  run_pretool "$cmd"

  if [[ "$amend" = "amend" ]]; then
    git -c core.hooksPath=/dev/null commit --amend --no-edit -q
  else
    git -c core.hooksPath=/dev/null commit -m "$subject" -q
  fi

  run_posttool "$cmd"
}

@test "amend of a just-acked commit does not advance the rotation slot" {
  # First, seed the repo with a base commit so HEAD exists.
  echo "seed" > seed.txt
  git add seed.txt
  git -c core.hooksPath=/dev/null commit -q -m "Seed"

  seed_rotation_at_rule4

  # Land a normal commit; PostToolUse should advance the slot.
  land_commit "Settings panel reaches Windows" "first.txt" "first"

  local rp_after_first
  rp_after_first=$(read_rp)

  # Re-seed pr=3 (rule 4) so the amend's PreToolUse ack also matches.
  printf 'pv=-1\npr=3\nrp=%s\nack_pending_sha=\n' "$rp_after_first" > "$STATE_FILE"

  # Now amend the just-landed commit (same parent = seed; suppression applies).
  land_commit "Settings panel reaches Windows on Linux too" "first.txt" "first amended" amend

  local rp_after_amend
  rp_after_amend=$(read_rp)

  [ "$rp_after_amend" = "$rp_after_first" ] || {
    printf 'amend advanced rp: was %s after first, is %s after amend\n' \
      "$rp_after_first" "$rp_after_amend" >&2
    return 1
  }
}

@test "regular new commit after acked commit advances the rotation slot" {
  echo "seed" > seed.txt
  git add seed.txt
  git -c core.hooksPath=/dev/null commit -q -m "Seed"

  seed_rotation_at_rule4

  # First normal commit.
  land_commit "Settings panel reaches Windows" "first.txt" "first"

  local rp_after_first
  rp_after_first=$(read_rp)

  # Re-seed pr=3 so the second commit's PreToolUse ack matches.
  printf 'pv=-1\npr=3\nrp=%s\nack_pending_sha=\n' "$rp_after_first" > "$STATE_FILE"

  # Second normal commit (different parent than the first's parent = different parent than seed).
  land_commit "Audio output covers macOS too" "second.txt" "second"

  local rp_after_second
  rp_after_second=$(read_rp)

  [ "$rp_after_second" != "$rp_after_first" ] || {
    printf 'regular commit did NOT advance rp: was %s after first, still %s after second\n' \
      "$rp_after_first" "$rp_after_second" >&2
    return 1
  }
}

@test "amend of a root commit (no parent) also keeps the rotation slot" {
  # Empty repo: the first commit IS the root, no seed beforehand.
  seed_rotation_at_rule4

  # Land the root commit.
  land_commit "Settings panel reaches Windows" "first.txt" "first"

  local rp_after_root
  rp_after_root=$(read_rp)

  printf 'pv=-1\npr=3\nrp=%s\nack_pending_sha=\n' "$rp_after_root" > "$STATE_FILE"

  # Amend the root commit (both parents empty; equal-comparison treats as amend).
  land_commit "Settings panel reaches Windows everywhere" "first.txt" "amended" amend

  local rp_after_amend
  rp_after_amend=$(read_rp)

  [ "$rp_after_amend" = "$rp_after_root" ] || {
    printf 'root-commit amend advanced rp: was %s, is %s after amend\n' \
      "$rp_after_root" "$rp_after_amend" >&2
    return 1
  }
}
