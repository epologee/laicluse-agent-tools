#!/usr/bin/env bats

setup() {
  GUARD="$BATS_TEST_DIRNAME/../hooks/guards/cache.sh"
  PATTERN=$(grep -A1 'grep -qiE' "$GUARD" | grep -oE '"\(het probleem is.*"' | sed 's/^"//; s/" *$//')
  [ -n "$PATTERN" ] || PATTERN=$(grep -oE '"\(het probleem is[^"]*"' "$GUARD" | sed 's/^"//; s/"$//')
  [ -n "$PATTERN" ]
}

matches() {
  echo "$1" | grep -qiE "$PATTERN"
}

@test "ignores js substring inside Dutch words after oude" {
  ! matches "oude en.yml (enige verschil: de zes lijstnummers)"
}

@test "still blocks stale JS bundle claims" {
  matches "de oude JS bundle staat nog in de browser"
}

@test "still blocks stale assets claims" {
  matches "vermoedelijk de oude assets van gisteren"
}
