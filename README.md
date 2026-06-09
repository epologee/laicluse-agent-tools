# l'Aicluse Agent Tools

Public, shareable agent tooling for Claude Code, Codex, and future coding
agents.

This repository is the public successor for selected tools from
`epologee/leclause-skills`. Migration happens plugin by plugin: install the new
marketplace first, replace only the plugins listed below, and keep `@leclause`
installed as long as you still use legacy plugins from it.

## First slice

The first plugins in this new marketplace are `how-plugins-work` and
`git-discipline`. `how-plugins-work` documents how plugin names, skill names,
marketplace aliases, Claude manifests, Codex manifests, and runtime caches
relate to each other. `git-discipline` is the first feature-complete migration
from legacy tooling to the new multi-agent home.

During the migration, `epologee/leclause-skills` remains the existing public
marketplace. Existing users do not need to uninstall or reinstall anything yet.
There is no automatic rename from `@leclause` to `@laicluse-agent-tools`; both
aliases can exist side by side. Legacy plugins disappear only after each
removed plugin has a working migration stub.

## Installation

Claude Code:

```bash
claude plugins marketplace add epologee/laicluse-agent-tools
claude plugins install how-plugins-work@laicluse-agent-tools
claude plugins install git-discipline@laicluse-agent-tools
```

Codex:

```bash
codex plugin marketplace add epologee/laicluse-agent-tools
codex plugin add how-plugins-work@laicluse-agent-tools
codex plugin add git-discipline@laicluse-agent-tools
```

For local development, point the marketplace at this working copy:

```bash
claude plugins marketplace add ./
codex plugin marketplace add ./
```

## Plumbing

Claude metadata is currently the hand-edited source. Codex metadata is
generated:

```bash
bin/plugin-adapters build .
bin/plugin-adapters check .
bin/plugin-adapters diff .
```

Plugin versions follow `1.0.<commit-count>` per package:

```bash
bin/plugin-versions --check
bin/plugin-versions --write
```

Enable the local git hooks in this clone:

```bash
git config core.hooksPath hooks
```

The pre-commit hook bumps versions, builds Codex adapters, and stages the
generated targets. The commit-msg hook requires `PII-Doublecheck: yes` because
this repository is public-facing.

## Local Storage

All first-party runtime state for l'Aicluse Agent Tools uses:

```bash
${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}
```

Agent-harness caches stay where the harness expects them, for example
`~/.claude/plugins/cache` and `~/.codex/plugins/cache`.
