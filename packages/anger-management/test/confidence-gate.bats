#!/usr/bin/env bats
# Contract tests for the anger-management diagnosis threshold.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  PROMPT="$REPO/packages/anger-management/bin/investigate.prompt.md"
  REPAIR="$REPO/packages/anger-management/skills/repair/SKILL.md"
}

@test "background investigation weighs the full history before fixing" {
  run grep -F "entire capture history" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "open captures" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "historical captures" "$PROMPT"
  [ "$status" -eq 0 ]
}

@test "background investigation requires confidence and mitigation level" {
  run grep -F "CONFIDENCE:" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "MITIGATION-LEVEL:" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "0.80" "$PROMPT"
  [ "$status" -eq 0 ]
}

@test "repair leaves the crumb trail open below the confidence threshold" {
  run grep -F "Confidence threshold" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "0.80" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "leave the captures open" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "MITIGATION-LEVEL" "$REPAIR"
  [ "$status" -eq 0 ]
}

@test "repair owns the mitigation decision before any self-improvement handoff" {
  run grep -F "self-improvement is only the execution backend" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "do not delegate the diagnosis" "$REPAIR"
  [ "$status" -eq 0 ]
}
