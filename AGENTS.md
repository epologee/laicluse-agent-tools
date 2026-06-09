# laicluse-agent-tools marketplace

Publieke l'Aicluse Agent Tools marketplace. Deze repo bevat de publieke,
deelbare plugins, skills, hooks en agent-adapters.

## Multi-agent marketplace

Dit is geen Claude-only en geen Codex-only repository. `packages/<plugin>/` is
de canonical source voor elke plugin; Claude en Codex krijgen daaruit hun eigen
runtime vorm via generated adapters. Nieuwe tooling hoort dus standaard
multi-agent ontworpen te worden, of expliciet agent-specifiek gemarkeerd te
worden met de suffix-conventie hieronder. Houd rekening met toekomstige agents
naast Claude en Codex.

## Schrijfstijl

Taal: Nederlands voor user-facing projectdocumentatie waar die stijl al past.
Code, manifests en commit messages blijven Engels. Vaktermen, package-namen en
framework-namen blijven onvertaald binnen Nederlandse zinnen.

## Lokale storage

Alle eigen runtime-state van l'Aicluse Agent Tools projecten gebruikt
`${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}` als root. Maak subdirectories
op componentnaam, bijvoorbeeld `~/.laicluse-agent/circus/`, niet op
marketplace- of repositorynaam (`toolbox`, `public`, `private`) en niet onder
nieuwe `~/.laicluse-*` of `~/.leclause-*` roots.

Agent-harness caches die Claude of Codex zelf beheert
(`~/.claude/plugins/cache`, `~/.codex/plugins/cache`, install indexes) blijven
waar de harness ze verwacht; schrijf daar geen first-party state tenzij de
harness API dat afdwingt. Bij legacy-state: lees/migreer uit oude paden,
schrijf daarna alleen naar `~/.laicluse-agent`.

## Migratiestatus

Deze repo is de publieke opvolger van geselecteerde tools uit
`epologee/leclause-skills`. Publiceer alleen changes die externe gebruikers
kunnen volgen met een werkende install- of migratieroute.

Tijdens de overgang mogen `how-plugins-work` en git-discipline tijdelijk op
meerdere plekken bestaan: oud publiek (`leclause-skills`) en nieuw publiek
(`laicluse-agent-tools`). Dat is bewuste migratieduplicatie, geen
DRY-findingslijst. Verwijder geen oude kopie zonder werkende migratie-stub voor
bestaande gebruikers. De publieke canonical plek wordt deze repo.

## Plugin-conventies

- Skills staan onder `packages/<plugin>/skills/<skill>/`.
- Gebruik `SKILL.md` alleen als de skill echt multi-agent-compatible is.
- Gebruik `SKILL.claude.md` én `SKILL.codex.md` wanneer de workflow per agent
  verschilt; `bin/plugin-adapters build .` materialiseert daaruit de runtime
  `SKILL.md` targets.
- Claude metadata blijft source; Codex manifests en `.agents/plugins/` zijn
  gegenereerde adapters.
- Geen symlinks; dezelfde layout moet op macOS, Linux en Windows werken.
