#!/usr/bin/env bats
# block-non-trivial.bats
# A non-trivial commit (2+ files or 6+ insertions) without a valid body is
# denied (exit 2). A non-trivial commit WITH a valid body passes (exit 0).
# The deny error message must contain violation code, example, and opt-out enum.

load helpers

@test "non-trivial commit without body is denied (exit 2)" {
  # 2 files, 30 insertions: above both trivial thresholds.
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Session boundary model for transaction events" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}

@test "non-trivial commit WITH valid body passes (exit 0)" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/foo.rb\nspec/controllers/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$VALID_TRAILERS"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/controllers/foo_spec.rb"

  local cmd
  cmd=$(commit_cmd_heredoc \
    "Controller boundary for incoming session events" \
    "$(printf 'When StartTransaction messages arrive with an invalid meter reading,\nthe previous implementation rejected the entire event and masked\nsession starts in the analytics pipeline.\n\nTests: spec/controllers/foo_spec.rb\nSlice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")
  cmd="$cmd # ack-rule4:essentie"

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]
}

@test "deny error message contains violation code" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Session boundary model for transaction events" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
  # stderr carries the deny message (bats captures combined output in $output).
  [[ "$output" == *"missing-body"* ]]
}

@test "deny error message contains a synthesized example" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Session boundary model for transaction events" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
  # The example body always contains a Slice trailer.
  [[ "$output" == *"Slice:"* ]]
  # And a Tests trailer.
  [[ "$output" == *"Tests:"* ]]
}

@test "deny error message contains the opt-out enum list" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Session boundary model for transaction events" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
  [[ "$output" == *"docs-only"* ]]
  [[ "$output" == *"config-only"* ]]
  [[ "$output" == *"migration-only"* ]]
  [[ "$output" == *"wip"* ]]
}
