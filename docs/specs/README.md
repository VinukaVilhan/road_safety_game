# Feature specs

Per-feature specifications for AI-assisted development.

| Layer | Purpose |
|-------|---------|
| [`../core-game-rules.md`](../core-game-rules.md) | **Canonical game rules** — zones, levels, scoring (do not contradict) |
| [`../../AGENTS.md`](../../AGENTS.md) | Workspace preferences + stable facts |
| [`.cursor/rules/`](../../.cursor/rules/) | Agent constraints (spec workflow) |
| **`docs/specs/*.md`** | **One change** — goal, requirements, acceptance criteria |

Agents are guided by [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc). Reference `@docs/core-game-rules.md` and `@docs/specs/your-file.md` when touching levels, zones, or scoring.

## Workflow

1. Copy [`_template.md`](./_template.md) to `YYYY-MM-DD-short-feature-name.md`.
2. Fill goal, scope, acceptance criteria, and affected surfaces **before** coding.
3. Start the Cursor task with: *Implement per `docs/specs/<filename>.md`. Do not edit the spec file.*
4. Mark sections **Done** / **N/A** as you ship.
5. **Update the spec kit in the same task as code** — see [Keeping docs in sync](#keeping-docs-in-sync).

## When to write a spec

| Write a spec | Skip (chat + AGENTS.md is enough) |
|--------------|-----------------------------------|
| New/changed level rules or TMX zone behaviour | Typo / copy fix |
| New scenario or scoring rubric | One-line bug in a single file |
| Multi-map zone convention change | Dependency bump |

## Keeping docs in sync

| Change type | Update |
|-------------|--------|
| Gameplay / zone / level logic | [`../core-game-rules.md`](../core-game-rules.md) |
| Work tracked in a dated spec | That spec — acceptance criteria, **Status**, implementation log |
| Shipped feature with no spec yet | Create `docs/specs/YYYY-MM-DD-….md` (retroactive is OK) |
| Long-lived agent preference | workspace `AGENTS.md` (brief bullet) |

Enforced by [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc).
