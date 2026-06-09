#!/usr/bin/env bats
# magic-comment-bypass.bats
# When the bash command carries the literal "# allow-wip-push" comment, the
# same wip range as wip-blocked.bats is allowed AND a bypass log line is
# written with mechanism "magic-comment".

load helpers

@test "git push # allow-wip-push allows the wip range and logs the bypass" {
  export GIT_SHIM_UPSTREAM="origin/feature/wip-gate"
  export GIT_SHIM_VERIFY_REFS="origin/feature/wip-gate"

  wip_shim_set_revlist "origin/feature/wip-gate..HEAD" $'cccccccccccc\ndddddddddddd'
  wip_shim_set_body "cccccccccccc" $'Add foo\n\nClean body.\n\nSlice: handler + spec\n'
  wip_shim_set_body "dddddddddddd" $'WIP do not ship\n\nQuick scratch.\n\nSlice: wip\n'
  wip_shim_set_subject "dddddddddddd" "WIP do not ship"

  run_dispatch 'git push  # allow-wip-push'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/push-wip-gate]"* ]]

  [ -f "$GIT_DISCIPLINE_WIP_PUSH_LOG" ]
  grep -q "|magic-comment" "$GIT_DISCIPLINE_WIP_PUSH_LOG"
}
