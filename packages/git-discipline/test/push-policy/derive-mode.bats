#!/usr/bin/env bats
# allow-comment: Pure-function unit tests for the push-policy resolver: derive_mode (mode from four facts), _protection_meaningful (branch-protection JSON triage), _classify_collaboration (author-count plus visibility to individual/closed/open).

load helpers

@test "no remote is local-only" {
  run derive_mode no write pushable individual
  [ "$status" -eq 0 ]
  [ "$output" = "local-only" ]
}

@test "no remote wins over everything" {
  run derive_mode no external protected open
  [ "$output" = "local-only" ]
}

@test "no write access forks" {
  run derive_mode yes external pushable individual
  [ "$output" = "external" ]
}

@test "unknown access is conservative" {
  run derive_mode yes unknown pushable individual
  [ "$output" = "external" ]
}

@test "protected default is pr-flow" {
  run derive_mode yes write protected closed
  [ "$output" = "pr-flow" ]
}

@test "unknown default is conservative" {
  run derive_mode yes write unknown individual
  [ "$output" = "pr-flow" ]
}

@test "own pushable solo is solo-trunk" {
  run derive_mode yes write pushable individual
  [ "$output" = "solo-trunk" ]
}

@test "pushable closed team is team-trunk" {
  run derive_mode yes write pushable closed
  [ "$output" = "team-trunk" ]
}

@test "pushable open maintainer is team-trunk" {
  run derive_mode yes write pushable open
  [ "$output" = "team-trunk" ]
}

@test "unknown collaboration is not solo" {
  run derive_mode yes write pushable unknown
  [ "$output" = "team-trunk" ]
}

@test "empty protection object is not meaningful" {
  result="$(printf '%s' '{"required_signatures":{"enabled":false},"enforce_admins":{"enabled":false},"allow_force_pushes":{"enabled":false}}' | _protection_meaningful)"
  [ "$result" = "false" ]
}

@test "required status checks make it meaningful" {
  result="$(printf '%s' '{"required_status_checks":{"contexts":["rspec","cucumber"]}}' | _protection_meaningful)"
  [ "$result" = "true" ]
}

@test "restrictions make it meaningful" {
  result="$(printf '%s' '{"restrictions":{"teams":[{"slug":"development"}]}}' | _protection_meaningful)"
  [ "$result" = "true" ]
}

@test "required PR reviews make it meaningful" {
  result="$(printf '%s' '{"required_pull_request_reviews":{"required_approving_review_count":0}}' | _protection_meaningful)"
  [ "$result" = "true" ]
}

@test "404 not-protected body is not meaningful" {
  result="$(printf '%s' '{"message":"Branch not protected","documentation_url":"https://docs.github.com"}' | _protection_meaningful)"
  [ "$result" = "false" ]
}

@test "one author name is individual" {
  run _classify_collaboration 1 private
  [ "$output" = "individual" ]
}

@test "one author name stays individual when public" {
  run _classify_collaboration 1 public
  [ "$output" = "individual" ]
}

@test "multiple names private is closed" {
  run _classify_collaboration 3 private
  [ "$output" = "closed" ]
}

@test "multiple names public is open" {
  run _classify_collaboration 3 public
  [ "$output" = "open" ]
}
