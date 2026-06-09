#!/usr/bin/env bats
# allow-comment: discipline carry-along marker. A commit stamped with a
# allow-comment: `Discipline: skip ...` trailer is exempt from the body schema,
# allow-comment: so a force-push after a rebase does not re-litigate commits
# allow-comment: whose subject-only bodies predate the discipline. The marker is
# allow-comment: an explicit, greppable opt-out, recognised in the shared
# allow-comment: validator so every enforcement path (commit, push, native
# allow-comment: commit-msg) honours it from one source.

load helpers

@test "a subject-only commit carrying the discipline-skip marker passes" {
  use_trailers "Discipline: skip due to rebase"
  local f
  f=$(write_fixture msg $'Capture charger make and model\n\nDiscipline: skip due to rebase\n')

  run invoke_validator "$f"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the same subject-only commit without the marker is rejected" {
  use_trailers ""
  local f
  f=$(write_fixture msg $'Capture charger make and model\n')

  run invoke_validator "$f"

  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-body"* ]]
}

@test "a Discipline trailer whose value is not skip-prefixed is still validated" {
  use_trailers "Discipline: enforced"
  local f
  f=$(write_fixture msg $'Capture charger make and model\n\nDiscipline: enforced\n')

  run invoke_validator "$f"

  [ "$status" -eq 1 ]
}
