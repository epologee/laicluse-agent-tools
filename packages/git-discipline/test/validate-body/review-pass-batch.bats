#!/usr/bin/env bats
# review-pass-batch rule: a commit body that names a review pass and
# lists 2+ findings as bullets is rejected. One finding per commit so
# each fate (fix, reject-with-evidence) is its own reviewable change.

load helpers

_body_review_pass_two_bullets() {
  cat <<MSG
Address pride findings on the IAP refactor

The pride contrarian pass surfaced three findings:
- Domain enum carries Dutch UI copy
- Two parallel @State variables for one outcome
- private(set) leaks the mock value into Release

Tests: spec/services/foo_spec.rb
Slice: handler + view
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
}

_body_review_pass_one_finding_prose() {
  cat <<MSG
Move IAP user copy out of the domain enum

The pride contrarian pass found that PurchaseOutcome.failed carried a
Dutch UI string in the domain layer; the view should map a typed
reason to its Dutch label, not the model. This commit moves the copy
to the view via a typed PurchaseFailureReason enum.

Tests: spec/services/foo_spec.rb
Slice: handler + view
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
}

_body_no_review_pass_with_bullets() {
  cat <<MSG
Drop several deprecated permissions from the manifest

The new permissions model removed:
- camera permission (replaced by photo picker)
- microphone permission (no audio capture in v2)
- contacts permission (never requested in v2 UI)

Tests: spec/manifest_spec.rb
Slice: config-only
MSG
}

@test "review-pass commit with 2+ bullet findings is rejected" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/foo.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/foo_spec.rb"

  local trailers='Tests: spec/services/foo_spec.rb
Slice: handler + view
Red-then-green: n/a (test fixture, no spec applies)'
  use_trailers "$trailers"

  local file
  file=$(write_fixture "rpb-batch.txt" "$(_body_review_pass_two_bullets)")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"review-pass-batch"* ]]
}

@test "review-pass commit addressing one finding in prose passes" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/foo.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/foo_spec.rb"

  local trailers='Tests: spec/services/foo_spec.rb
Slice: handler + view
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed'
  use_trailers "$trailers"

  local file
  file=$(write_fixture "rpb-one.txt" "$(_body_review_pass_one_finding_prose)")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "non-review-pass commit with bullets passes (no keyword trigger)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="manifest.json"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/manifest_spec.rb"

  local trailers='Tests: spec/manifest_spec.rb
Slice: config-only'
  use_trailers "$trailers"

  local file
  file=$(write_fixture "rpb-bullets-ok.txt" "$(_body_no_review_pass_with_bullets)")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}
