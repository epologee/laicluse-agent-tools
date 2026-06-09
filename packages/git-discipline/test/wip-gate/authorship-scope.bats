#!/usr/bin/env bats
# allow-comment: authorship scoping. The body discipline is personal, so the
# allow-comment: gate only judges commits that are OURS: authored by the current
# allow-comment: git identity, or rebase-co-authored (committer is us, or a
# allow-comment: Co-authored-by trailer names us). A purely-carried teammate
# allow-comment: commit is never held to the schema.

load helpers

setup_authorship() {
  export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=0
  export GIT_SHIM_ORIGIN_HEAD="refs/remotes/origin/master"
  export GIT_SHIM_VERIFY_REFS="origin/master"
  export GIT_SHIM_UPSTREAM="origin/master"
}

@test "purely-carried teammate commit is not held to the body schema" {
  setup_authorship

  wip_shim_set_revlist "origin/master..HEAD" $'teammate0001'
  wip_shim_set_subject "teammate0001" "Refactor the widget pipeline"
  wip_shim_set_body "teammate0001" "Refactor the widget pipeline"
  wip_shim_set_author "teammate0001" "teammate@example.com"
  wip_shim_set_committer "teammate0001" "teammate@example.com"

  run_dispatch 'git push'

  [ "$status" -eq 0 ]
  [[ "$output" != *"push-body-gate"* ]]
}

@test "teammate commit we rebase-co-authored (committer is us) is enforced" {
  setup_authorship

  wip_shim_set_revlist "origin/master..HEAD" $'coauth000001'
  wip_shim_set_subject "coauth000001" "Original teammate commit, rebased by us"
  wip_shim_set_body "coauth000001" "Original teammate commit, rebased by us"
  wip_shim_set_author "coauth000001" "teammate@example.com"
  wip_shim_set_committer "coauth000001" "dev@example.com"

  run_dispatch 'git push'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
}

@test "teammate commit with a Co-authored-by trailer naming us is enforced" {
  setup_authorship

  wip_shim_set_revlist "origin/master..HEAD" $'coauth000002'
  wip_shim_set_subject "coauth000002" "Teammate commit co-authored by us"
  wip_shim_set_body "coauth000002" \
    $'Teammate commit co-authored by us\n\nCo-authored-by: Dev <dev@example.com>\n'
  wip_shim_set_author "coauth000002" "teammate@example.com"
  wip_shim_set_committer "coauth000002" "teammate@example.com"

  run_dispatch 'git push'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
}

@test "our own newly-written subject-only commit is still enforced" {
  setup_authorship

  wip_shim_set_revlist "origin/master..HEAD" $'ourown000001'
  wip_shim_set_subject "ourown000001" "Add the thing without a body"
  wip_shim_set_body "ourown000001" "Add the thing without a body"
  wip_shim_set_author "ourown000001" "dev@example.com"
  wip_shim_set_committer "ourown000001" "dev@example.com"

  run_dispatch 'git push'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
}
