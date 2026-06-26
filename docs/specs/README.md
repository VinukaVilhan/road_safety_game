# Feature specs — Road Safety Game

Per-feature specifications for AI-assisted development on the **Flutter / Flame** driving game.

| Layer | Purpose |
|-------|---------|
| [`../core-game-rules.md`](../core-game-rules.md) | **Canonical gameplay rules** — TMX zones, levels, scoring (do not contradict) |
| [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) | **Level system reference** — curriculum, progress, unlock graph, new-level checklist |
| [`2026-06-26-spec-driven-kit.md`](./2026-06-26-spec-driven-kit.md) | **Spec kit meta** — completion gate, git tracking, agent workflow |
| [`../../AGENTS.md`](../../AGENTS.md) | Workspace preferences + stable facts |
| [`.cursor/rules/`](../../.cursor/rules/) | Hard agent constraints (spec workflow) |
| **`docs/specs/*.md`** | **One change** — goal, requirements, acceptance criteria |

Agents are guided by [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc). Reference `@docs/core-game-rules.md` and `@docs/specs/your-file.md` when touching levels, zones, or scoring.

## Workflow

1. Copy [`_template.md`](./_template.md) to `YYYY-MM-DD-short-feature-name.md`.
2. Fill goal, scope, acceptance criteria, and affected surfaces **before** coding.
3. Start the Cursor task with: *Implement per `docs/specs/<filename>.md`. Do not edit the spec file.*
4. Mark sections **Done** / **N/A** as you ship; archive or delete specs for abandoned work.
5. **Update the spec kit in the same task as code** — see [Keeping docs in sync](#keeping-docs-in-sync).

### Specs vs `.cursor/plans/`

| Use | For |
|-----|-----|
| **`docs/specs/*.md`** | Shippable feature: requirements, acceptance criteria, rollout, spec-kit checklist |
| **`.cursor/plans/*.plan.md`** | Large multi-step exploration or todo sequencing — link from the spec if both exist |

## When to write a spec

| Write a spec | Skip (chat + AGENTS.md is enough) |
|--------------|-----------------------------------|
| New/changed level rules or TMX zone behaviour | Typo / copy fix |
| New scenario or scoring rubric | One-line bug in a single file |
| Multi-map zone convention change | Dependency bump |
| New level in curriculum (unlock, map, scenario) | Styling-only HUD tweak |

## Keeping docs in sync

Agents must run the **completion gate** in [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc) before finishing any non-trivial task (automatic — do not wait for the user to request doc updates).

| Change type | Update |
|-------------|--------|
| Gameplay / zone / level / scoring logic | [`../core-game-rules.md`](../core-game-rules.md) — matching § section(s) |
| Level curriculum, unlock graph, new-level DoD | [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) + core rules §7 |
| Work tracked in a dated spec | That spec — acceptance criteria, **Status**, **Implementation log** |
| Shipped feature with no spec yet | Create `docs/specs/YYYY-MM-DD-….md` (retroactive is OK) |
| Long-lived agent preference or ops fact | workspace `AGENTS.md` (brief bullet; **not** for routine spec-kit sync) |

Enforced by [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc).

## Dated specs (index)

| Spec | Status | Topic |
|------|--------|-------|
| [`2026-06-26-spec-driven-kit.md`](./2026-06-26-spec-driven-kit.md) | Done | Agent spec kit + completion gate |
| [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) | Done | Level curriculum, progress, unlock graph |
| [`2026-06-26-adverse-weather-rain.md`](./2026-06-26-adverse-weather-rain.md) | Done | Rain overlay + wet-road physics |
| [`2026-06-26-roundabout-spawn-map-load.md`](./2026-06-26-roundabout-spawn-map-load.md) | Done (rules TBD) | Roundabout TMX spawn; rules disabled |
| [`2026-06-26-level-briefing-carousel.md`](./2026-06-26-level-briefing-carousel.md) | Done | Unified pre-level briefing carousel + registry |
| [`2026-06-17-road-crossing-fail-zone.md`](./2026-06-17-road-crossing-fail-zone.md) | Done | Zone_Fail_WT wheel contact on road-crossing |
| [`2026-06-17-internet-radio-api.md`](./2026-06-17-internet-radio-api.md) | Done | In-app Radio Browser API + lesson gating |
