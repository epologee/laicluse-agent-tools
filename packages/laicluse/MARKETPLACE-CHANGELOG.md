# laicluse-agent-tools marketplace changelog

Marketplace-wide news. Per-plugin changes go in
`packages/<plugin>/CHANGELOG.md` and surface via
`/laicluse:whats-new <plugin>`. This file covers the ecosystem:
new plugins joining, plugins leaving, marketplace-level
conventions, shared infrastructure, and breaking changes that
span multiple plugins.

## [2026-06] Marketplace live, eight plugins ported from leclause

The public l'Aicluse Agent Tools marketplace now ships:
`how-plugins-work`, `self-improvement`, `git-discipline` (was `gitgit`),
`intervision`, `anger-management`, `autonomous` + `rover` (split from the
old `autonomous`), and `clipboard`. Each replaced plugin left a tombstone
in `leclause-skills` whose SessionStart notice carries the migration
commands. Existing `.autonomous/` loop files stay compatible with the new
rover. The `laicluse` meta plugin (this one) carries `/laicluse:whats-new`
for re-reading any plugin's latest CHANGELOG section on demand.
