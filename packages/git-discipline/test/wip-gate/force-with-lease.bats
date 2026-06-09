#!/usr/bin/env bats
# force-with-lease.bats
# --force / --force-with-lease do NOT bypass the gate. Force-vs-non-force is
# orthogonal to wip-vs-clean.

load helpers

@test "git push --force-with-lease still blocks on wip commits" {
  export GIT_SHIM_UPSTREAM="origin/feature/wip-gate"
  export GIT_SHIM_VERIFY_REFS="origin/feature/wip-gate"

  wip_shim_set_revlist "origin/feature/wip-gate..HEAD" $'gggggggggggg'
  wip_shim_set_body "gggggggggggg" $'WIP scratch\n\nNot ready.\n\nSlice: wip\n'
  wip_shim_set_subject "gggggggggggg" "WIP scratch"

  run_dispatch 'git push --force-with-lease'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
}

@test "git push --force still blocks on wip commits" {
  export GIT_SHIM_UPSTREAM="origin/feature/wip-gate"
  export GIT_SHIM_VERIFY_REFS="origin/feature/wip-gate"

  wip_shim_set_revlist "origin/feature/wip-gate..HEAD" $'gggggggggggg'
  wip_shim_set_body "gggggggggggg" $'WIP scratch\n\nNot ready.\n\nSlice: wip\n'
  wip_shim_set_subject "gggggggggggg" "WIP scratch"

  run_dispatch 'git push --force'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
}
