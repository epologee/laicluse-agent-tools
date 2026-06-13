# laicluse-agent-tools marketplace changelog

Marketplace-wide news. Per-plugin changes go in
`packages/<plugin>/CHANGELOG.md` and surface via
`/whats-new <plugin>` (or `/laicluse-agent-tools:whats-new <plugin>` when a
namespaced form is needed). This file covers the ecosystem:
new plugins joining, plugins leaving, marketplace-level
conventions, shared infrastructure, and breaking changes that
span multiple plugins.

## [2026-06] dont-do-that moved from leclause

`dont-do-that` now ships as `dont-do-that@laicluse-agent-tools`. Claude Code
keeps the guardrail hook stack; Codex receives `/duh` and `/just-a-question`
through the generated adapter package. Install the successor, then uninstall
the legacy `dont-do-that@leclause` copy.

## [2026-06] Marketplace live, eight plugins ported from leclause

The public l'Aicluse Agent Tools marketplace now ships:
`how-plugins-work`, `self-improvement`, `git-discipline` (was `gitgit`),
`intervision`, `anger-management`, `autonomous` + `rover` (split from the
old `autonomous`), and `clipboard`. Each replaced plugin left a tombstone
in `leclause-skills` whose SessionStart notice carries the migration
commands. Existing `.autonomous/` loop files stay compatible with the new
rover. The `laicluse-agent-tools` utility plugin (this one) carries `/whats-new`
for re-reading any plugin's latest CHANGELOG section on demand.
