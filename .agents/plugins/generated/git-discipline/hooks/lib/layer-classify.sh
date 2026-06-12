#!/bin/bash
# packages/git-discipline/hooks/lib/layer-classify.sh
#
# Single-purpose layer-classification library.
# Sourced by example-synth.sh and prepare-commit-msg.
#
# Public functions:
#   classify_path <path>
#     Echoes one of: frontend backend spec migration config docs other.
#
#   classify_diff <newline-separated-paths-on-stdin>
#     Reads paths from stdin, classifies each, emits one summary line with
#     the sorted unique layers that had at least one match, e.g. "backend spec".
#
#   suggest_slice <classified-summary>
#     Maps a classify_diff summary to a human-readable Slice token candidate.
#
#   suggest_tests <newline-separated-paths-on-stdin>
#     Extracts spec-pattern paths and prints them comma-separated.

# ---------------------------------------------------------------------------
# Regexes (ERE, applied via [[ =~ ]])
# ---------------------------------------------------------------------------

_LC_SPEC_RE='(spec/|test/|__tests__/|_spec\.|_test\.|\.test\.|\.feature)'
_LC_FRONTEND_RE='(\.css$|\.scss$|\.html$|\.tsx$|\.ts$|\.jsx$|\.js$|app/javascript/)'
_LC_BACKEND_RE='(\.rb$|\.py$|\.go$|\.java$|app/controllers/|app/models/|app/services/)'
_LC_MIGRATION_RE='(db/migrate/|migrations/)'
_LC_CONFIG_RE='(\.yml$|\.yaml$|\.json$|\.toml$|\.lock$|^Gemfile$|^package\.json$|\.config\.)'
_LC_DOCS_RE='(\.md$|\.txt$|\.rst$|^README|^CHANGELOG)'

# ---------------------------------------------------------------------------
# classify_path <path>
# ---------------------------------------------------------------------------
# Spec is checked first: spec paths often also match backend regex.
classify_path() {
  local p="$1"
  if [[ "$p" =~ $_LC_SPEC_RE ]];      then printf 'spec';      return; fi
  if [[ "$p" =~ $_LC_MIGRATION_RE ]]; then printf 'migration'; return; fi
  if [[ "$p" =~ $_LC_FRONTEND_RE ]];  then printf 'frontend';  return; fi
  if [[ "$p" =~ $_LC_BACKEND_RE ]];   then printf 'backend';   return; fi
  if [[ "$p" =~ $_LC_CONFIG_RE ]];    then printf 'config';    return; fi
  if [[ "$p" =~ $_LC_DOCS_RE ]];      then printf 'docs';      return; fi
  printf 'other'
}

# ---------------------------------------------------------------------------
# classify_diff
# Reads newline-separated paths from stdin, returns a single sorted summary.
# Example output: "backend frontend spec"
# ---------------------------------------------------------------------------
classify_diff() {
  local seen_frontend=0 seen_backend=0 seen_spec=0
  local seen_migration=0 seen_config=0 seen_docs=0 seen_other=0

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local layer
    layer=$(classify_path "$path")
    case "$layer" in
      frontend)  seen_frontend=1  ;;
      backend)   seen_backend=1   ;;
      spec)      seen_spec=1      ;;
      migration) seen_migration=1 ;;
      config)    seen_config=1    ;;
      docs)      seen_docs=1      ;;
      *)         seen_other=1     ;;
    esac
  done

  # Emit in alphabetical order so output is deterministic.
  local summary=""
  [[ "$seen_backend"   -eq 1 ]] && summary="${summary:+$summary }backend"
  [[ "$seen_config"    -eq 1 ]] && summary="${summary:+$summary }config"
  [[ "$seen_docs"      -eq 1 ]] && summary="${summary:+$summary }docs"
  [[ "$seen_frontend"  -eq 1 ]] && summary="${summary:+$summary }frontend"
  [[ "$seen_migration" -eq 1 ]] && summary="${summary:+$summary }migration"
  [[ "$seen_other"     -eq 1 ]] && summary="${summary:+$summary }other"
  [[ "$seen_spec"      -eq 1 ]] && summary="${summary:+$summary }spec"

  printf '%s\n' "${summary:-other}"
}

# ---------------------------------------------------------------------------
# suggest_slice <classified-summary>
# Maps the space-separated summary from classify_diff to a Slice token.
# ---------------------------------------------------------------------------
suggest_slice() {
  local summary="$1"

  # Single-layer opt-out tokens: map to the validated enum values that
  # validate-body.sh recognises and exempts from the 10-char length rule.
  case "$summary" in
    docs)                       printf 'docs-only'       ; return ;;
    config)                     printf 'config-only'     ; return ;;
    migration)                  printf 'migration-only'  ; return ;;
    spec)                       printf 'spec-only'       ; return ;;
    other)                      printf 'chore-deps'      ; return ;;
  esac

  # Single-layer non-opt-out tokens: pad to >= 10 chars so the free-text
  # Slice length rule (>= 10 chars) is satisfied when the user accepts the
  # template suggestion as-is.
  case "$summary" in
    backend)                    printf 'backend layer'   ; return ;;
    frontend)                   printf 'frontend layer'  ; return ;;
  esac

  # Multi-layer output: join with " + ". All multi-layer combinations are
  # >= 10 chars (shortest: "backend + spec" = 14).
  local joined
  joined=$(printf '%s' "$summary" | sed 's/ / + /g')
  printf '%s' "$joined"
}

# ---------------------------------------------------------------------------
# suggest_tests
# Reads newline-separated paths from stdin, prints comma-separated spec paths.
# ---------------------------------------------------------------------------
suggest_tests() {
  local first=1
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local layer
    layer=$(classify_path "$path")
    if [[ "$layer" == "spec" ]]; then
      if [[ "$first" -eq 1 ]]; then
        printf '%s' "$path"
        first=0
      else
        printf ', %s' "$path"
      fi
    fi
  done
  # Emit a trailing newline only when at least one spec path was found.
  [[ "$first" -eq 0 ]] && printf '\n'
}
