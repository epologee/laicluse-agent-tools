# l'Aicluse Agent Tools

Publieke, deelbare agent tooling voor Claude Code, Codex en toekomstige
coding-agents.

Deze repo is de publieke opvolger van geselecteerde tools uit
`epologee/leclause-skills`. De migratie gebeurt plugin voor plugin: installeer
eerst de nieuwe marketplace, vervang daarna alleen de plugins die hieronder
staan, en laat `@leclause` staan zolang je nog oude plugins gebruikt.

## Eerste slice

De eerste plugins in deze nieuwe marketplace zijn `how-plugins-work` en
`git-discipline`. `how-plugins-work` legt vast hoe plugin-namen, skill-namen,
marketplace-aliassen, Claude manifests, Codex manifests en runtime caches zich
tot elkaar verhouden. `git-discipline` is de eerste feature-complete migratie
van oude tooling naar de nieuwe multi-agent plek.

Tijdens de migratie blijft `epologee/leclause-skills` de bestaande publieke
marketplace. Bestaande gebruikers hoeven nu niets te deinstalleren of te
herinstalleren. Een rename van `@leclause` naar `@laicluse-agent-tools` gebeurt
niet automatisch; beide aliases kunnen naast elkaar bestaan. Oude plugins
verdwijnen pas nadat er per verwijderde plugin een werkende migratie-stub is.

## Installatie

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

Voor lokale ontwikkeling kun je de marketplace naar de working copy laten
wijzen:

```bash
claude plugins marketplace add ./
codex plugin marketplace add ./
```

## Plumbing

Claude metadata is voorlopig de hand-edite bron. Codex metadata wordt
gegenereerd:

```bash
bin/plugin-adapters build .
bin/plugin-adapters check .
bin/plugin-adapters diff .
```

Pluginversies volgen `1.0.<commit-count>` per package:

```bash
bin/plugin-versions --check
bin/plugin-versions --write
```

Activeer de lokale git hooks in deze clone:

```bash
git config core.hooksPath hooks
```

De pre-commit hook bumpet versies, bouwt Codex adapters en staged de gegenereerde
targets. De commit-msg hook vraagt expliciet om `PII-Doublecheck: yes`, omdat
deze repo uiteindelijk publiek bedoeld is.

## Lokale storage

Alle first-party runtime-state voor l'Aicluse Agent Tools gebruikt:

```bash
${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}
```

Agent-harness caches blijven waar de harness ze verwacht, bijvoorbeeld
`~/.claude/plugins/cache` en `~/.codex/plugins/cache`.
