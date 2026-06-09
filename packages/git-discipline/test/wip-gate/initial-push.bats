#!/usr/bin/env bats
# initial-push.bats
# A branch with no upstream yet (initial push). The guard's range becomes the
# local ref alone; rev-list scans every reachable commit on the new branch,
# and a wip commit in that history is still detected.

load helpers

@test "initial push (no upstream) still detects wip commits in branch history" {
  # No upstream: GIT_SHIM_UPSTREAM stays empty, the @{u} resolution fails,
  # and the guard falls back to scanning HEAD alone.
  export GIT_SHIM_UPSTREAM=""
  export GIT_SHIM_VERIFY_REFS=""

  wip_shim_set_revlist "feature/wip-gate" $'eeeeeeeeeeee\nffffffffffff'
  wip_shim_set_body "eeeeeeeeeeee" $'Initial scaffold\n\nFirst commit.\n\nSlice: handler + spec\n'
  wip_shim_set_body "ffffffffffff" $'WIP rough draft\n\nNot ready.\n\nSlice: wip\n'
  wip_shim_set_subject "ffffffffffff" "WIP rough draft"

  run_dispatch 'git push -u origin feature/wip-gate'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
  [[ "$output" == *"WIP rough draft"* ]]
}
