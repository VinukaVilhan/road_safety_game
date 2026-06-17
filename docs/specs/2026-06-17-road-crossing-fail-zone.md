# Road-crossing Zone_Fail_WT (wrong-turn) fail

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | |
| **Created** | 2026-06-17 |
| **Related** | `road-crossing.tmx`, `markings_zebra_crossing`, `markings_stop_yield` |

---

## Goal

When the player drives into the red **Zone_Fail_WT** area on road-crossing maps (past the stop line / wrong route), the practical level **ends immediately** with a clear failure message — matching junction maps' wrong-turn behaviour.

## Non-goals

- Changing zig-zag wait / Park countdown rules
- Adding new maps or art assets
- Penalty-only mode (instant fail, not a scored checklist row)

---

## Background

- [`../core-game-rules.md`](../core-game-rules.md) §2 Driving zones, §3 Road-crossing levels
- `road-crossing.tmx` already has `Wrong_Turn_Layer` / `Zone_Fail_WT` at the stop line
- Bug: fail strip height (~35px) is thinner than the car (60px); center-based overlap could miss rear wheels backing into the zone

---

## Requirements

### Functional

1. Entering `Zone_Fail_WT` on `road-crossing.tmx` calls `onTestFailed` and stops the car.
2. Detection uses **any wheel** inside the zone rect (not only car-center AABB overlap).
3. Default fail copy explains wrong route at zebra crossing; overridable via TMX `fail_message`.
4. Level briefing and assistant rubric mention wrong-turn instant fail.

### Maps / zones

| Zone class | Expected behaviour |
|------------|-------------------|
| `Zone_Fail_WT` | Immediate fail on first wheel contact |
| `Zig_Zag` | Unchanged — Park + wait countdown |
| `Zone_Finish` | Unchanged — pass after zebra step |

---

## Technical design

| Item | Detail |
|------|--------|
| Engine | `_carContactsDrivingZone`, `_anyWheelInsideRect`, `_handleZoneEntry` |
| TMX | `fail_message` on `Wrong_Turn_Layer` object group |
| UI | `game_screen.dart` briefing for zebra + stop/yield scenarios |
| Assistant | `assistant_context_builder.dart` road-crossing rubric |

---

## Acceptance criteria

- [x] Driving rear wheels into `Zone_Fail_WT` fails the level (zebra + stop/yield scenarios)
- [x] Failure message shown in attempt summary
- [x] Completing zebra wait + finish still passes
- [x] `fail_message` on TMX layer respected
- [x] **Spec kit updated** — core rules §3, this spec, `spec-driven.mdc`

---

## Test plan

### Manual

1. Play **Zebra Crossings** — after spawn, reverse into red strip → immediate fail with wrong-route message.
2. Play correctly: yellow approach → Park in grey zig-zag → cross forward → green finish → pass.
3. Play **Stop & Yield Lines** — same wrong-turn fail behaviour.

---

## Spec kit updates

- [x] [`../core-game-rules.md`](../core-game-rules.md) — §2, §3
- [x] This spec — **Status** → Done
- [x] `.cursor/rules/spec-driven.mdc` — kit bootstrap
- [x] Workspace `AGENTS.md` — spec kit pointer

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-17 | Wheel-based Zone_Fail_WT contact; TMX fail_message; briefing + rubric; spec kit |
