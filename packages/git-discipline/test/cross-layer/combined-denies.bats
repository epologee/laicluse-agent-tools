#!/usr/bin/env bats
# combined-denies.bats
# When commit-subject and commit-body would both deny on the same git commit
# call, the dispatcher must emit both messages in a single exit-2 response
# so the operator fixes both in one round-trip instead of two. Independence
# is also covered: when only one layer denies, only that layer's message
# surfaces.

load helpers

@test "subject ack reminder denies first; body nudge waits for the retry" {
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$TMPDIR_TEST/commit-rule-state"

  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/services/foo.rb\nspec/services/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local cmd='git commit -m "Use policy on the read path"'
  local json
  json=$(pretool_bash_json "$cmd")
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"ack-rule"* ]]
  [[ "$output" == *"missing-body"* ]]
}

@test "subject ack alone surfaces only the subject deny" {
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$TMPDIR_TEST/commit-rule-state"

  # Trivial commit (1 file, 1 insertion) -> commit-body sets GIT_DISCIPLINE_TRIVIAL_OK
  # and validate_body returns silently.
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 1 insertion(+)"
  export GIT_SHIM_DIFF_NAMES="docs/foo.md"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local cmd='git commit -m "Use policy on the read path"'
  run bash "$DISPATCH" <<< "$(pretool_bash_json "$cmd")"

  [ "$status" -eq 2 ]
  [[ "$output" == *"ack-rule"* ]]
  [[ "$output" != *"missing-body"* ]]
}

@test "additionalContext JSON from a collected guard is forwarded on stdout" {
  # Pending rotation pre-populated to rule 4 so ack-rule4 satisfies subject.
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$TMPDIR_TEST/commit-rule-state"

  # Trivial commit (1 file, 1 insertion) so commit-body skips silently.
  # Subject is 60 chars: triggers commit-format's aspirational nudge via
  # dd_emit_pre_context (additionalContext JSON on stdout, no deny).
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 1 insertion(+)"
  export GIT_SHIM_DIFF_NAMES="docs/foo.md"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local subject="Use policy on the read path with extra padding to reach"
  # Pad to exactly 60 chars.
  while [ "${#subject}" -lt 60 ]; do subject="${subject}x"; done
  local cmd="git commit -m \"${subject}\" # ack-rule4:essentie"
  run bash "$DISPATCH" <<< "$(pretool_bash_json "$cmd")"

  [ "$status" -eq 0 ]
  # additionalContext payload must reach stdout so Claude Code surfaces it.
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"<=50"* ]]
}

@test "guard crash (non-zero rc that is not 2) aborts the dispatcher" {
  # Inject a fake guard that exits 1 on stderr. A bug in any guard must NOT
  # be silently swallowed by the collector.
  local fake_dispatch="$TMPDIR_TEST/fake-dispatch.sh"
  local fake_guard_dir="$TMPDIR_TEST/fake-guards"
  mkdir -p "$fake_guard_dir"

  cat > "$fake_guard_dir/crashing-guard.sh" <<'EOF'
guard_crashing() {
  printf 'simulated guard crash\n' >&2
  exit 1
}
EOF

  cat > "$fake_dispatch" <<EOF
#!/bin/bash
DIR="$(dirname "$DISPATCH")"
source "\$DIR/lib/common.sh"
source "$fake_guard_dir/crashing-guard.sh"
DD_DENY_MESSAGES=()
_dd_run_collect guard_crashing "{}"
echo "should not reach here"
EOF
  chmod +x "$fake_dispatch"

  run bash "$fake_dispatch"

  [ "$status" -eq 1 ]
  [[ "$output" == *"simulated guard crash"* ]]
  [[ "$output" != *"should not reach here"* ]]
}

@test "body nudge alone surfaces only the body context after ack passes" {
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$TMPDIR_TEST/commit-rule-state"

  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/services/foo.rb\nspec/services/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local cmd='git commit -m "Use policy on the read path" # ack-rule4:essentie'
  run bash "$DISPATCH" <<< "$(pretool_bash_json "$cmd")"

  [ "$status" -eq 2 ]
  [[ "$output" == *"missing-body"* ]]
  [[ "$output" != *"reminder"* ]]
}
