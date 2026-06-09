#!/usr/bin/env bats
# WHY block length validation and anti-copy-paste detection.

load helpers

# Standard trailers that the shim will return for why-block tests.
WHY_TRAILERS="Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"

# ---------------------------------------------------------------------------
# WHY block length (3 cases)
# ---------------------------------------------------------------------------

@test "WHY block with only one short line fails with why-too-short" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$WHY_TRAILERS"

  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

Short why.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "why-short.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"why-too-short"* ]]
}

@test "WHY block with two non-empty lines passes" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$WHY_TRAILERS"

  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction arrives with an invalid meter reading, the event
was previously rejected, which masked session starts in analytics.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "why-two-lines.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "WHY block with >= 60 chars ending in period passes as one line" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$WHY_TRAILERS"

  # 73-char single-line WHY ending with a period.
  local long_why="Previously the event was rejected wholesale; now only the bad reading is dropped."

  local body
  body="$(cat <<MSG
Expose session boundary on transaction events

${long_why}

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "why-long-one-line.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Anti-copy-paste (2 cases)
# ---------------------------------------------------------------------------

@test "duplicate WHY block identical to previous commit is rejected" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$WHY_TRAILERS"

  local why_text="When StartTransaction arrives with an invalid reading, the event
was previously rejected, which masked session starts in analytics."

  # Make the git shim return one previous commit whose WHY is identical.
  export GIT_SHIM_LOG_HASHES="abc1234"
  export GIT_SHIM_LOG_BODY="$(cat <<MSG
Previous commit subject

${why_text}

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"

  local body
  body="$(cat <<MSG
Expose session boundary on transaction events

${why_text}

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "dup-why.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"duplicate-why"* ]]
}

@test "GIT_DISCIPLINE_VALIDATE_CONTEXT=<sha> excludes the sha itself from duplicate-why iteration" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$WHY_TRAILERS"

  local why_text="When StartTransaction arrives with an invalid reading, the event
was previously rejected, which masked session starts in analytics."

  export GIT_SHIM_LOG_HASHES="abc1234"
  export GIT_SHIM_LOG_BODY="$(cat <<MSG
Same subject as the validated commit

${why_text}

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"

  local body
  body="$(cat <<MSG
Expose session boundary on transaction events

${why_text}

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "self-sha.txt" "$body")

  export GIT_DISCIPLINE_VALIDATE_CONTEXT=abc1234
  run invoke_validator "$file"
  unset GIT_DISCIPLINE_VALIDATE_CONTEXT
  [ "$status" -eq 0 ]
  [[ "$output" != *"duplicate-why"* ]]
}

@test "novel WHY block that differs from previous commits passes" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$WHY_TRAILERS"

  export GIT_SHIM_LOG_HASHES="abc1234"
  export GIT_SHIM_LOG_BODY="$(cat <<'MSG'
Previous commit subject

A completely different reason for the previous commit, unrelated
to anything in the current commit being validated here at all.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"

  local file
  file=$(write_fixture "novel-why.txt" "$VALID_BODY_TEMPLATE")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}
