#!/usr/bin/env bats
# packages/git-discipline/test/migrated-hooks/commit-trailers.bats
#
# Verifies the absorbed ~/.claude/hooks/block-coauthored-trailer.sh behaviour
# now lives in guards/commit-trailers.sh:
#
#   - Co-Authored-By with @anthropic.com is denied (exit 2) with mnemonic.
#   - Co-Authored-By with a non-anthropic email passes (exit 0).
#   - GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1 bypasses the guard silently.
#   - A commit body without any Co-Authored-By trailer passes silently.

load helpers

@test "anthropic Co-Authored-By trailer is denied with commit-trailers mnemonic" {
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: docs-only\nCo-Authored-By: AI <noreply@anthropic.com>')"
  local cmd
  cmd=$(cat <<'INNER_CMD'
git commit -m "$(cat <<'EOF'
Use policy on the read path

The body explains the why in two short sentences.
Wrap each line at the seventy-two char ceiling.

Slice: docs-only
Co-Authored-By: AI <noreply@anthropic.com>
EOF
)" # ack-rule4:essentie
INNER_CMD
)

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[git-discipline/commit-trailers]"* ]]
  [[ "$output" == *"anthropic"* ]]
}

@test "human Co-Authored-By trailer (non-anthropic) passes" {
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: docs-only\nCo-Authored-By: A Human <human@example.com>')"
  local cmd
  cmd=$(cat <<'INNER_CMD'
git commit -m "$(cat <<'EOF'
Use policy on the read path

The body explains the why in two short sentences.
Wrap each line at the seventy-two char ceiling.

Slice: docs-only
Co-Authored-By: A Human <human@example.com>
EOF
)" # ack-rule4:essentie
INNER_CMD
)

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]
}

@test "GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1 bypasses the anthropic block" {
  export GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: docs-only\nCo-Authored-By: AI <noreply@anthropic.com>')"

  local cmd
  cmd=$(cat <<'INNER_CMD'
git commit -m "$(cat <<'EOF'
Use policy on the read path

The body explains the why in two short sentences.
Wrap each line at the seventy-two char ceiling.

Slice: docs-only
Co-Authored-By: AI <noreply@anthropic.com>
EOF
)" # ack-rule4:essentie
INNER_CMD
)

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]
}

@test "commit without any Co-Authored-By trailer passes silently" {
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: docs-only')"
  local cmd
  cmd=$(cat <<'INNER_CMD'
git commit -m "$(cat <<'EOF'
Use policy on the read path

The body explains the why in two short sentences.
Wrap each line at the seventy-two char ceiling.

Slice: docs-only
EOF
)" # ack-rule4:essentie
INNER_CMD
)

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]
  [[ "$output" != *"commit-trailers"* ]]
}
