#!/usr/bin/env bash
# allow-comment: Shared load for the push-policy BATS suite. Sources the resolver so its pure functions (derive_mode, _protection_meaningful, _classify_collaboration) are callable; the source guard in git-repo-policy keeps main() from running.

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HELPER_DIR/../../skills/push-policy/git-repo-policy"
