#!/usr/bin/env bats
# parser-equivalence.bats
# Verifies that PreToolUse string parsing and direct file-input parsing
# produce equivalent validate_body verdicts for the same commit message
# expressed in multiple syntactic forms.
#
# For each form the test:
#   1. Extracts the message via dd_extract_commit_message (same as commit-body.sh).
#   2. Writes it to a temp file and calls validate_body directly.
# Both paths must agree on BOTH the exit code AND the leading violation code
# (or both succeed with exit 0).
#
# GIT_DISCIPLINE_TRIVIAL_OK is only set when the test specifically targets trivial
# commit behaviour; it is not applied globally to avoid masking parser
# differences.

load helpers

# ---------------------------------------------------------------------------
# Shared valid commit body fixtures
# ---------------------------------------------------------------------------

_VALID_SUBJECT="Expose session boundary on transaction events"
_VALID_WHY="$(printf 'When StartTransaction messages arrive with an invalid meter\nreading we previously rejected the entire event.')"
_VALID_TRAILERS="$(printf 'Tests: spec/services/session_spec.rb\nSlice: handler + service + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

_setup_valid_shim() {
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf \
    'Tests: spec/services/session_spec.rb\nSlice: handler + service + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
}

# ---------------------------------------------------------------------------
# invoke_via_extract <bash-command>
# Runs dd_extract_commit_message on the command, writes result to a temp file,
# calls validate_body, and returns (stdout: validator output, exit: validator rc).
# ---------------------------------------------------------------------------
invoke_via_extract() {
  local cmd="$1"
  bash -c "
    source '$VALIDATOR'
    msg=\$(source '$(dirname "$VALIDATOR")/../lib/common.sh' 2>/dev/null; \
           dd_extract_commit_message '$cmd' 2>/dev/null || true)
    if [[ -z \"\$msg\" ]]; then
      printf 'empty-extract\n'
      exit 2
    fi
    tmpf=\$(mktemp)
    printf '%s' \"\$msg\" > \"\$tmpf\"
    validate_body \"\$tmpf\" 2>&1
    rc=\$?
    rm -f \"\$tmpf\"
    exit \$rc
  " 2>&1
}

# violation_code_from <output>
# Extracts the leading violation code from the first line of validator output.
violation_code_from() {
  printf '%s' "$1" | head -1 | cut -d: -f1
}

# ---------------------------------------------------------------------------
# Form 1: simple -m "subject only" with GIT_DISCIPLINE_TRIVIAL_OK=1
# Tests that trivial-commit bypass works consistently through both parser paths.
# ---------------------------------------------------------------------------

@test "equivalence: single-line -m form with GIT_DISCIPLINE_TRIVIAL_OK=1 (both pass)" {
  _setup_valid_shim
  export GIT_DISCIPLINE_TRIVIAL_OK=1

  local cmd
  cmd="git commit -m \"${_VALID_SUBJECT}\""

  # File-input path.
  local file
  file=$(write_fixture "form1.txt" "${_VALID_SUBJECT}")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path. Use && / || to capture exit code safely under set -e.
  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  # Both must agree on exit code.
  [ "$file_status" -eq "$extract_status" ]
  # Both must agree on violation code (both empty when exit 0).
  [ "$file_code" = "$extract_code" ]
}

# ---------------------------------------------------------------------------
# Form 2: heredoc <<'EOF' (standard Claude Code multi-line form)
# ---------------------------------------------------------------------------

@test "equivalence: heredoc EOF form agrees on exit code and violation code" {
  _setup_valid_shim

  local body
  body="${_VALID_SUBJECT}"$'\n\n'"${_VALID_WHY}"$'\n\n'"${_VALID_TRAILERS}"

  local cmd
  cmd="git commit -m \"\$(cat <<'EOF'
${body}
EOF
)\""

  # File-input path.
  local file
  file=$(write_fixture "form2.txt" "$body")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path. Use && / || to capture exit code safely under set -e.
  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
}

# ---------------------------------------------------------------------------
# Form 3: missing body (invalid) - both paths must agree on violation code
# ---------------------------------------------------------------------------

@test "equivalence: missing-body verdict matches between paths (exit code + violation code)" {
  _setup_valid_shim
  unset GIT_DISCIPLINE_TRIVIAL_OK

  local subject="Subject without body"
  local cmd="git commit -m \"${subject}\""

  # File-input path.
  local file
  file=$(write_fixture "form3.txt" "$subject")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path. Use && / || to capture exit code safely under set -e.
  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
  # Violation code must be non-empty (both agree it failed).
  [ -n "$file_code" ]
}

# ---------------------------------------------------------------------------
# Form 4: body with embedded $ and quotes
# ---------------------------------------------------------------------------

@test "equivalence: body with dollar signs and quotes agrees on exit code and violation code" {
  _setup_valid_shim

  local body
  body="$(printf '%s\n\n%s\n\n%s' \
    "Expose session boundary on transaction events" \
    "The variable \$session_id must not be nil at ingestion time.
This guards against a nil-deref that only appeared under load." \
    "${_VALID_TRAILERS}")"

  # File-input path.
  local file
  file=$(write_fixture "form4.txt" "$body")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Heredoc form keeps $ literal in the payload.
  local cmd
  cmd="git commit -m \"\$(cat <<'GITEOF'
${body}
GITEOF
)\""

  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd")
  extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
}

# ---------------------------------------------------------------------------
# Form 5: missing-slice violation - both paths must agree
# ---------------------------------------------------------------------------

@test "equivalence: missing-slice verdict matches between paths (exit code + violation code)" {
  # Shim returns no Slice trailer.
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf \
    'Tests: spec/services/session_spec.rb\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  unset GIT_DISCIPLINE_TRIVIAL_OK

  local body
  body="$(printf '%s\n\n%s\n\n%s' \
    "Expose session boundary on transaction events" \
    "When StartTransaction messages arrive with an invalid meter
reading we previously rejected the entire event." \
    "$(printf 'Tests: spec/services/session_spec.rb\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")"

  # File-input path.
  local file
  file=$(write_fixture "form5.txt" "$body")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path via heredoc.
  local cmd
  cmd="git commit -m \"\$(cat <<'EOF'
${body}
EOF
)\""
  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
  # Both must report missing-slice specifically.
  [ "$file_code" = "missing-slice" ]
}

# ---------------------------------------------------------------------------
# Form 6: --message=value form
# Tests that --message=value is parsed equivalently to -m "value".
# ---------------------------------------------------------------------------

@test "equivalence: --message=value form agrees on exit code and violation code" {
  _setup_valid_shim
  unset GIT_DISCIPLINE_TRIVIAL_OK

  # --message=<subject> carries only the subject line, so both the file-input
  # path and the extract path should produce the same missing-body violation.
  local subject="Subject only via message flag"

  # File-input path: write just the subject, no body.
  local file
  file=$(write_fixture "form6.txt" "$subject")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path using --message=value form.
  local cmd
  cmd="git commit --message=\"${subject}\""

  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  # Both paths see the same subject-only message and must agree on the verdict.
  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
}

# ---------------------------------------------------------------------------
# Form 6b: -am combined-flag form
# `git commit -am "subject"` combines -a (auto-stage) with -m (message). The
# parser regex (-[a-zA-Z]*m|--message) matches -am the same way it matches -m,
# so the extract path sees the same subject-only message as the file path and
# both must fail with missing-body. The pride pass found that this form was
# never asserted in the cross-layer suite even though the rover communiques
# hedged on whether -am was covered.
# ---------------------------------------------------------------------------

@test "equivalence: -am combined-flag form agrees on exit code and violation code" {
  _setup_valid_shim
  unset GIT_DISCIPLINE_TRIVIAL_OK

  local subject="Subject without body"
  local cmd="git commit -am \"${subject}\""

  # File-input path.
  local file
  file=$(write_fixture "form6b.txt" "$subject")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path.
  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
  # Subject-only message without trivial flag must fail with missing-body.
  [ "$file_code" = "missing-body" ]
}

# ---------------------------------------------------------------------------
# Form 6c: multiple -m flags concatenate to subject + body
# `git commit -m "subject" -m "body"` produces a two-paragraph commit at git
# execution time. The current PreToolUse parser only captures the first -m
# literal (head -1 in the regex pipeline), so the extract path sees only the
# subject while the file path sees both paragraphs. This test asserts
# equivalence so the divergence is visible: any future parser change that
# concatenates multiple -m values closes the gap and the test stays green.
# ---------------------------------------------------------------------------

@test "equivalence: multiple -m flags agree on exit code and violation code" {
  _setup_valid_shim
  unset GIT_DISCIPLINE_TRIVIAL_OK

  local subject="subject"
  local body_para="body block with Slice: docs-only"

  # File-input path: the two paragraphs git would produce from two -m flags.
  local body
  body="${subject}"$'\n\n'"${body_para}"
  local file
  file=$(write_fixture "form6c.txt" "$body")
  run invoke_validator_file "$file"
  local file_status=$status
  local file_code
  file_code=$(violation_code_from "$output")

  # Extract path: two -m flags on the command line.
  local cmd="git commit -m \"${subject}\" -m \"${body_para}\""
  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?
  local extract_code
  extract_code=$(violation_code_from "$extract_out")

  [ "$file_status" -eq "$extract_status" ]
  [ "$file_code" = "$extract_code" ]
}

# ---------------------------------------------------------------------------
# Form 7: -F <file> scope demonstration
# The -F flag reads a message from a file at git-execution time, not at
# PreToolUse parse time. dd_extract_commit_message sees the literal string
# "-F /path/to/file" in the command and cannot read the file contents (it
# would need to execute in the user's shell context with the right cwd).
# This test documents that parser scope limit: the extract path returns
# empty (exit 2 / skip) while the file path can validate fine.
# ---------------------------------------------------------------------------

@test "scope-limit: -F form produces empty extract (documents parser scope limit)" {
  _setup_valid_shim

  local body
  body="${_VALID_SUBJECT}"$'\n\n'"${_VALID_WHY}"$'\n\n'"${_VALID_TRAILERS}"

  local file
  file=$(write_fixture "form7-msg.txt" "$body")

  # Extract path: dd_extract_commit_message sees only the command string.
  # It cannot open /some/file at parse time, so it returns empty.
  local cmd
  cmd="git commit -F \"${file}\""

  local extract_out extract_status
  extract_out=$(invoke_via_extract "$cmd") && extract_status=0 || extract_status=$?

  # Expected: exit 2 (skip, cannot extract) and output signals empty extract.
  # The parser cannot read the -F file; this is a documented scope boundary.
  [ "$extract_status" -eq 2 ]
}
