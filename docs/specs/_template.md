# [Feature title]

| Field | Value |
|-------|--------|
| **Status** | Draft / In progress / Done |
| **Author** | |
| **Created** | YYYY-MM-DD |
| **Related** | Level id / map asset (optional) |

---

## Goal

One paragraph: what gameplay problem this solves.

## Non-goals

- What we are **not** changing in this task.

---

## Background

- Read [`../core-game-rules.md`](../core-game-rules.md) — cite section numbers (e.g. §2 Driving zones, §3 Road-crossing).
- Relevant map: `assets/tiles/….tmx`
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

---

## Technical design

### Flutter / Flame

| Item | Detail |
|------|--------|
| Primary file(s) | `lib/game/realistic_car_game.dart`, … |
| TMX changes | layer / object / properties |
| UI | `lib/screens/game_screen.dart`, reports |

---

## Acceptance criteria

- [ ] …
- [ ] Manual playtest on target level(s)
- [ ] **Spec kit updated** (same task as code)

---

## Test plan

### Manual

1. Launch level from Road Markings category.
2.

---

## Spec kit updates (required when shipping)

- [ ] [`../core-game-rules.md`](../core-game-rules.md) — § section(s): …
- [ ] This spec — acceptance criteria checked; **Status** → Done
- [ ] `AGENTS.md` — only if new stable preference
- [ ] N/A — internal refactor only

---

## Implementation log

| Date | Note |
|------|------|
| | |
