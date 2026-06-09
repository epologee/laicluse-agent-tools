#!/usr/bin/env bats
# clean-range.bats
# Push range with zero wip commits passes silently.

load helpers

@test "git push with no wip commits in range is allowed" {
  export GIT_SHIM_UPSTREAM="origin/feature/wip-gate"
  export GIT_SHIM_VERIFY_REFS="origin/feature/wip-gate"

  wip_shim_set_revlist "origin/feature/wip-gate..HEAD" $'aaaaaaaaaaaa\nbbbbbbbbbbbb'
  wip_shim_set_body "aaaaaaaaaaaa" $'Add foo\n\nBody describing why.\n\nSlice: handler + spec\n'
  wip_shim_set_body "bbbbbbbbbbbb" $'Add bar\n\nMore body.\n\nSlice: docs-only\n'

  run_dispatch 'git push'

  [ "$status" -eq 0 ]
  [[ "$output" != *"push-wip-gate"* ]]
}
