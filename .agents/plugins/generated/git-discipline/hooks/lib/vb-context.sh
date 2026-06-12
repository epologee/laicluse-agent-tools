#!/bin/bash
# allow-comment: GIT_DISCIPLINE_VALIDATE_CONTEXT picks the "current change" source for validate_body and ui-touch so the same lib serves PreToolUse (staged), PostToolUse (HEAD delta), and push-body-gate (range walk).

_vb_delta_files() {
  case "${GIT_DISCIPLINE_VALIDATE_CONTEXT:-staged}" in
    staged) git diff --cached --name-only 2>/dev/null || true ;;
    HEAD|head) git show --name-only --format= HEAD 2>/dev/null | grep -v '^$' || true ;;
    *) git show --name-only --format= "${GIT_DISCIPLINE_VALIDATE_CONTEXT}" 2>/dev/null | grep -v '^$' || true ;;
  esac
}

_vb_delta_shortstat() {
  case "${GIT_DISCIPLINE_VALIDATE_CONTEXT:-staged}" in
    staged) git diff --cached --shortstat 2>/dev/null || true ;;
    HEAD|head) git show --shortstat --format= HEAD 2>/dev/null || true ;;
    *) git show --shortstat --format= "${GIT_DISCIPLINE_VALIDATE_CONTEXT}" 2>/dev/null || true ;;
  esac
}

_vb_show_blob() {
  local path="$1"
  case "${GIT_DISCIPLINE_VALIDATE_CONTEXT:-staged}" in
    staged) git show ":$path" 2>/dev/null || true ;;
    HEAD|head) git show "HEAD:$path" 2>/dev/null || true ;;
    *) git show "${GIT_DISCIPLINE_VALIDATE_CONTEXT}:$path" 2>/dev/null || true ;;
  esac
}
