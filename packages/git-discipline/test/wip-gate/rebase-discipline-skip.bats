#!/usr/bin/env bats
# allow-comment: end-to-end carry-along through push-body-gate. After a rebase
# allow-comment: rewrites commits that were already on origin under an earlier
# allow-comment: SHA, a force-push re-feeds them through the body gate. Commits
# allow-comment: stamped with the `Discipline: skip ...` marker are exempt; an
# allow-comment: unmarked own subject-only commit is still gated.

load helpers

setup_scope() {
  export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=0
  export GIT_SHIM_ORIGIN_HEAD="refs/remotes/origin/master"
  export GIT_SHIM_VERIFY_REFS="origin/master"
  export GIT_SHIM_UPSTREAM="origin/master"
}

@test "a rebased own commit carrying the discipline-skip marker is not re-litigated" {
  setup_scope

  wip_shim_set_revlist "origin/master..HEAD" $'rebased00001'
  wip_shim_set_subject "rebased00001" "Capture charger make and model"
  wip_shim_set_body "rebased00001" \
    $'Capture charger make and model\n\nDiscipline: skip due to rebase'
  wip_shim_set_show "rebased00001" " 3 files changed, 30 insertions(+)" $'a\nb\nc'

  run_dispatch 'git push --force-with-lease'

  [ "$status" -eq 0 ]
  [[ "$output" != *"push-body-gate"* ]]
}

@test "the same commit without the marker is gated on push" {
  setup_scope

  wip_shim_set_revlist "origin/master..HEAD" $'rebased00002'
  wip_shim_set_subject "rebased00002" "Capture charger make and model"
  wip_shim_set_body "rebased00002" "Capture charger make and model"
  wip_shim_set_show "rebased00002" " 3 files changed, 30 insertions(+)" $'a\nb\nc'

  run_dispatch 'git push --force-with-lease'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
}
