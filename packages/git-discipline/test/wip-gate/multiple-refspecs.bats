#!/usr/bin/env bats
# allow-comment: a push is always "this branch -> that branch", regardless of whether the bash form is bare, single-positional, multi-refspec, or wrapped in pipes. The gate therefore always asks git itself for the natural range (@{u}..HEAD) when the bash command does not explicitly name a single <local>:<dest> refspec. Shell metachars (pipes, semicolons, 2>&1) no longer confuse the parser into "exotic" form.

load helpers

@test "git push with multiple refspecs uses @{u}..HEAD for HEAD's branch" {
  export GIT_SHIM_UPSTREAM="origin/feature"
  export GIT_SHIM_VERIFY_REFS="origin/feature"

  wip_shim_set_revlist "origin/feature..HEAD" $'iiiiiiiiiiii'
  wip_shim_set_body "iiiiiiiiiiii" $'WIP draft\n\nDraft.\n\nSlice: wip\n'
  wip_shim_set_subject "iiiiiiiiiiii" "WIP draft"

  run_dispatch 'git push origin branch1:branch1 branch2:branch2'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
  [[ "$output" == *"WIP draft"* ]]
}

@test "git push with shell pipe after the args still parses as two-positional" {
  export GIT_SHIM_UPSTREAM="origin/main"
  export GIT_SHIM_VERIFY_REFS="origin/main"

  wip_shim_set_revlist "origin/main..main" $'wipwipwipwip'
  wip_shim_set_body "wipwipwipwip" $'WIP\n\nDraft.\n\nSlice: wip\n'
  wip_shim_set_subject "wipwipwipwip" "WIP"

  run_dispatch 'git push origin main 2>&1 | tail -3'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
}

@test "git push --all uses @{u}..HEAD and catches wip on HEAD's branch" {
  export GIT_SHIM_UPSTREAM="origin/feature"
  export GIT_SHIM_VERIFY_REFS="origin/feature"

  wip_shim_set_revlist "origin/feature..HEAD" $'wipwipwipwip'
  wip_shim_set_body "wipwipwipwip" $'WIP\n\nDraft.\n\nSlice: wip\n'

  run_dispatch 'git push --all'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-wip-gate]"* ]]
}
