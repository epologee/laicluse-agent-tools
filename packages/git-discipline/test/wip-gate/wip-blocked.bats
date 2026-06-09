#!/usr/bin/env bats
# wip-blocked.bats
# Push range containing one Slice: wip commit is blocked. The diagnostic
# names the commit by SHA and subject, and points at the bypass paths.

load helpers

@test "git push with a wip commit in range is denied with push-wip-gate mnemonic" {
  export GIT_SHIM_UPSTREAM="origin/feature/wip-gate"
  export GIT_SHIM_VERIFY_REFS="origin/feature/wip-gate"

  wip_shim_set_revlist "origin/feature/wip-gate..HEAD" $'cccccccccccc\ndddddddddddd'
  wip_shim_set_body "cccccccccccc" $'Add foo\n\nClean body.\n\nSlice: handler + spec\n'
  wip_shim_set_body "dddddddddddd" $'WIP do not ship\n\nQuick scratch.\n\nSlice: wip\n'
  wip_shim_set_subject "dddddddddddd" "WIP do not ship"

  run_dispatch 'git push'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
  [[ "$output" == *"ddddddd"* ]]
  [[ "$output" == *"WIP do not ship"* ]]
  [[ "$output" == *"GIT_DISCIPLINE_ALLOW_WIP_PUSH"* ]]
  [[ "$output" == *"# allow-wip-push"* ]]
}
