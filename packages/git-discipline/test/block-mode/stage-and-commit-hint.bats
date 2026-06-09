#!/usr/bin/env bats
# stage-and-commit-hint.bats
# When a commit is denied for a staging-dependent reason (a Tests or
# Red-then-green path that is not in the index) AND the same command stages
# with git add before committing, the deny explains that the add has not run
# yet, instead of leaving a bare path-not-found.

load helpers

setup_staging_scenario() {
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="app/models/x.rb"
  export GIT_SHIM_LS_TREE_OUTPUT=""
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Tests: spec/missing_spec.rb\nSlice: handler layer\nRed-then-green: n/a (fixture scenario for the gate test itself)\nVerified: operator-confirmed')"
}

@test "stage-then-commit deny explains the unrun add" {
  setup_staging_scenario
  local body
  body=$(printf 'First reason line that explains the change.\nSecond reason line for the why paragraph.')
  local cmd
  cmd=$(commit_cmd_heredoc "Boundary handler for incoming events" "$body")
  cmd="git add spec/missing_spec.rb && $cmd # ack-rule4:essentie"

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"tests-path-not-found"* ]]
  [[ "$output" == *"Stage in a separate call first"* ]]
}

@test "a bare commit deny carries no staging hint" {
  setup_staging_scenario
  local body
  body=$(printf 'First reason line that explains the change.\nSecond reason line for the why paragraph.')
  local cmd
  cmd=$(commit_cmd_heredoc "Boundary handler for incoming events" "$body")
  cmd="$cmd # ack-rule4:essentie"

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"tests-path-not-found"* ]]
  [[ "$output" != *"Stage in a separate call first"* ]]
}
