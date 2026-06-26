# Road Safety Game — documentation (tracked)

Spec kit and canonical rules for the **Flutter / Flame** practical driving game (`road_safety_game/`).

## Tracked in git (spec kit)

| Path | Purpose |
|------|---------|
| [`core-game-rules.md`](./core-game-rules.md) | **Canonical gameplay rules** — TMX zones, levels, scoring, scenarios |
| [`specs/2026-06-26-level-system-design.md`](./specs/2026-06-26-level-system-design.md) | **Level system architecture** — curriculum, unlock graph, new-level checklist |
| [`specs/2026-06-26-spec-driven-kit.md`](./specs/2026-06-26-spec-driven-kit.md) | **Spec kit meta** — how agents use docs + completion gate |
| [`specs/README.md`](./specs/README.md) | How to write and use per-feature specs |
| [`specs/_template.md`](./specs/_template.md) | Copy for each new feature spec |
| [`specs/YYYY-MM-DD-*.md`](./specs/) | One spec per shippable change |

See [`specs/README.md`](./specs/README.md) for the full dated spec index.

Agents: [`.cursor/rules/spec-driven.mdc`](../.cursor/rules/spec-driven.mdc) (always-on **completion gate**) · workspace [`AGENTS.md`](../../AGENTS.md)

## What this app is

| | |
|--|--|
| **Product** | Road safety learning app — practical driving levels (TMX maps), theory tests, road signs, minigames, AI assistant. |
| **Gameplay source of truth** | `docs/core-game-rules.md` + dated specs — do not contradict without an explicit spec change. |
| **Progress** | Local Isar + Firestore sync when signed in; level unlocks via `LevelProgressService`. |

Before building or changing zones, levels, scoring, or scenarios, read [`core-game-rules.md`](./core-game-rules.md) and cite affected § sections in your spec **Background**.

## Local only (not in git)

| Path | Purpose |
|------|---------|
| `lib/config/assistant_secrets.json` | Gemini API key (see `.gitignore`) |
| `.cursor/mcp.json` | Local MCP tokens (if added) — rules under `.cursor/rules/` **are** tracked |

## Workflow (quick)

1. Copy `specs/_template.md` → `specs/YYYY-MM-DD-feature-name.md`
2. Cite affected sections of `core-game-rules.md` in Background
3. Prompt: *Implement per `docs/specs/….md`. Do not edit the spec file.*
4. **Same task as code:** run the agent **completion gate** in `.cursor/rules/spec-driven.mdc` — update core rules, spec checkboxes, `AGENTS.md` only for stable preferences
