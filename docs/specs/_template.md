# [Feature title]

| Field | Value |
|-------|--------|
| **Status** | Draft / In progress / Done |
| **Author** | |
| **Created** | YYYY-MM-DD |
| **Related** | Level id / map asset (optional) |

---

## Goal

One paragraph: what gameplay problem this solves and for whom (player / curriculum author).

## Non-goals

- What we are **not** changing in this task.

---

## Background

- Read [`../core-game-rules.md`](../core-game-rules.md) — cite section numbers (e.g. §2 Driving zones, §3 Road-crossing, §7 Level curriculum).
- If adding or changing a level in the catalog, read [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md).
- Relevant map: `assets/tiles/….tmx`
- Relevant `AGENTS.md` facts or file paths only — do not duplicate long domain docs.
- Existing behaviour to preserve.

---

## Requirements

### Functional

1.
2.
3.

### Maps / zones (if applicable)

| Zone class | Expected behaviour |
|------------|-------------------|
| | |

### Scoring / UI (if applicable)

- Checklist rows, failure messages, assistant rubric:

### Session / lifecycle (if applicable)

- Radio, assistant, progress sync boundaries (e.g. lesson end, leave `GameScreen`):

---

## Technical design

### Flutter / Flame

| Item | Detail |
|------|--------|
| Primary file(s) | `lib/game/driving_game.dart`, … |
| Zone mixins | `lib/game/zones/` (if new topic) |
| TMX changes | layer / object / properties |
| Level catalog | `lib/services/content/driving_levels_service.dart` |
| UI | `lib/screens/driving/game_screen.dart`, `lib/widgets/driving/` |

### Config / secrets

- Document in comments or README only — never commit `assistant_secrets.json` or API keys.

---

## Acceptance criteria

- [ ] …
- [ ] Manual playtest on target level(s)
- [ ] No regression on: …
- [ ] **Spec kit updated** (same task as code — see below)

---

## Test plan

### Manual

1. Launch level from level selection (correct module / unlock state).
2.

---

## Rollout (if needed)

- Map asset deploy, Firestore schema, or feature-flag notes:

---

## Spec kit updates (required when shipping)

Run the **agent completion gate** in [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc) — same task as code, without waiting for the user to ask.

Check all that apply:

- [ ] [`../core-game-rules.md`](../core-game-rules.md) — § section(s): …
- [ ] [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — if curriculum / unlock / new-level DoD changed
- [ ] This spec — acceptance criteria checked; **Status** → Done; **Implementation log** line
- [ ] `AGENTS.md` — **only** new stable preference or ops fact (not routine spec-kit sync)
- [ ] N/A — internal refactor; no gameplay rule change

---

## Implementation log

| Date | Note |
|------|------|
| | PR / commit; list spec-kit files updated |
