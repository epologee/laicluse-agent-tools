#!/usr/bin/env bats
# trivial-allow.bats
# Trivial commit detection: <= 1 file AND <= 5 insertions passes without body.
# Exceeding either threshold triggers block-mode deny.

load helpers

@test "1-file 3-insertion commit without body passes (trivial)" {
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 3 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="README.md"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Typo in README" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
}

@test "1-file 5-insertion commit without body passes (boundary)" {
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 5 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="lib/helper.rb"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Guard against nil on session close" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
}

@test "1-file 6-insertion commit without body is denied (over insertion threshold)" {
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 6 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="lib/big.rb"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Expand helper logic" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}

@test "2-file 3-insertion commit without body is denied (over file-count threshold)" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 3 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Bump two files" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}
