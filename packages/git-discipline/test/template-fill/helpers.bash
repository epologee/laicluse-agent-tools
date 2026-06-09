#!/usr/bin/env bash
# Shared helpers for the template-fill BATS suite.
#
# Provides paths to the classify library and the prepare-commit-msg hook,
# plus fixture-repo helpers for integration tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

CLASSIFY_LIB="$REPO_ROOT/packages/git-discipline/hooks/lib/layer-classify.sh"
PREPARE_HOOK="$REPO_ROOT/packages/git-discipline/skills/commit-discipline/git-hooks/prepare-commit-msg"
INSTALL_SH="$REPO_ROOT/packages/git-discipline/skills/install-hooks/lib/install.sh"
SOURCE_HOOKS_DIR="$REPO_ROOT/packages/git-discipline/skills/commit-discipline/git-hooks"

# ---------------------------------------------------------------------------
# run_classify_path <path>
# Sources classify lib in a subshell and calls classify_path.
# ---------------------------------------------------------------------------
run_classify_path() {
  bash -c "source '$CLASSIFY_LIB'; classify_path '$1'"
}

# ---------------------------------------------------------------------------
# run_classify_diff <newline-separated-paths>
# Sources classify lib in a subshell and pipes paths through classify_diff.
# ---------------------------------------------------------------------------
run_classify_diff() {
  local paths="$1"
  bash -c "source '$CLASSIFY_LIB'; printf '%s\n' '$paths' | classify_diff"
}

# ---------------------------------------------------------------------------
# run_suggest_slice <summary>
# ---------------------------------------------------------------------------
run_suggest_slice() {
  bash -c "source '$CLASSIFY_LIB'; suggest_slice '$1'"
}

# ---------------------------------------------------------------------------
# run_suggest_tests <newline-separated-paths>
# ---------------------------------------------------------------------------
run_suggest_tests() {
  local paths="$1"
  bash -c "source '$CLASSIFY_LIB'; printf '%s\n' \"\$PATHS\" | suggest_tests" PATHS="$paths"
}

# ---------------------------------------------------------------------------
# Fixture repo setup (used by live-prepare.bats)
# ---------------------------------------------------------------------------
setup_fixture_repo() {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  install -d "$TEST_REPO"

  pushd "$TEST_REPO" >/dev/null
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  popd >/dev/null

  export HOME="$BATS_TEST_TMPDIR/home"
  install -d "$HOME/.claude/plugins"
}

# ---------------------------------------------------------------------------
# run_install <repo-dir> <args...>
# ---------------------------------------------------------------------------
run_install() {
  local repo="$1"
  shift
  run bash -c "cd '$repo' && bash '$INSTALL_SH' $*"
}
