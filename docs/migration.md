# Migratie naar l'Aicluse Agent Tools

Status: publiek, eerste migratie-slice actief.

## Besluit

De oude publieke marketplace `epologee/leclause-skills` wordt niet in een keer
gerenamed. Deze repo wordt de nieuwe publieke canonical plek onder de
marketplace-alias `laicluse-agent-tools`.

Tijdens de overgang:

- `leclause-skills` blijft de bestaande publieke bron voor gebruikers.
- `laicluse-agent-tools` is de nieuwe publieke plek voor multi-agent-compatible
  opvolgers.
- `how-plugins-work` en git-discipline mogen tijdelijk op meerdere plekken
  bestaan. Dat is migratieduplicatie, geen DRY-probleem.
- De nieuwe canonical plugin-naam voor git-discipline is
  `git-discipline@laicluse-agent-tools`; de oude publieke naam `gitgit@leclause`
  blijft legacy totdat de oude marketplace een plugin-specifieke migratie-stub
  kan dragen.
- Migratiestatus hoort hier en in package-specifieke changelogs/stubs, niet in
  `how-plugins-work`. Die skill documenteert alleen plugin-mechanics zoals
  naming, aliases, cachegedrag en adapter-sync.

## Voor bestaande gebruikers

Installeer de nieuwe marketplace naast de oude:

```bash
claude plugins marketplace add epologee/laicluse-agent-tools
```

Marketplace aliases zijn installatie-identiteiten; `@leclause` wordt niet
vanzelf `@laicluse-agent-tools`.

Wanneer een plugin verhuist, blijft in de oude marketplace minstens een
migratie-stub achter die uitlegt welke oude install weg kan en welke nieuwe
install ervoor terugkomt. Pas daarna mag de echte oude plugin verdwijnen.

## Voor agents

Werk plugin voor plugin. Houd Claude metadata als bron en genereer Codex
adapters met `bin/plugin-adapters`. Houd runtime-state onder
`${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}`.
