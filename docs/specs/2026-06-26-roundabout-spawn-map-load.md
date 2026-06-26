# Roundabout map load & rules hold

| Field | Value |
|-------|--------|
| **Status** | Done (rules TBD) |
| **Author** | Agent |
| **Created** | 2026-06-26 |
| **Related** | `junctions_roundabout_basics`, `roundabout-junction.tmx` |

---

## Goal

Load `roundabout-junction.tmx` from the TMX spawn point without instant fail before play. Centralize spawn → car/camera placement for all maps.

## Non-goals

- Defining roundabout pass/fail rules (user will specify later).
- Editing TMX zone geometry in this task.

---

## Background

- [`../core-game-rules.md`](../core-game-rules.md) — §4 Junction levels, §4b Rules-disabled levels.
- Level catalog: [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — `junctions_roundabout_basics` in unlock graph.
- Spawn overlaps `Zone_Fail_WT` near bottom of map → immediate fail on first frame when rules were enabled.

---

## Requirements

### Functional

1. Resolve `Spawn_Layer` / `Spawn_Point` and place car + camera via `_applyPlayerSpawnToWorld`.
2. Load TMX once per level setup.
3. `junctions_roundabout_basics`: `enableDrivingRules: false` — collision and visuals only.

### Maps / zones

| Zone class | Expected behaviour |
|------------|-------------------|
| All rule zones | **Not loaded** while `enableDrivingRules: false` |
| `Obstacles_Layer` | Collision only — player can drive freely |

---

## Technical design

### Flutter / Flame

| Item | Detail |
|------|--------|
| Map load / spawn | `lib/game/map/tiled_map_loader.dart` — shared TMX load helpers |
| Rules flag | `GameLevel.enableDrivingRules` → `RealisticCarGame.drivingRulesEnabled` |
| Spawn safety | `_seedDrivingZonesAtSpawn` prevents spawn-adjacent fail strips on rules-enabled maps |
| Level row | `driving_levels_service.dart` — `junctions_roundabout_basics` |

---

## Acceptance criteria

- [x] Roundabout Basics starts without fail dialog before driving.
- [x] Car spawns at TMX point `(440, 892)` not map centre.
- [x] Camera frames spawn without black void at map edge.
- [ ] Roundabout gameplay rules — **pending user spec**.
- [x] **Spec kit updated** (same task as code).

---

## Test plan

### Manual

1. Unlock Roundabout Basics; start level — no instant fail dialog.
2. Confirm car at TMX spawn, not map centre.
3. Drive around — collision works; no zone pass/fail prompts.
4. Quit and retry — spawn behaviour unchanged.

---

## Spec kit updates (required when shipping)

Run the **agent completion gate** in [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc).

- [x] [`../core-game-rules.md`](../core-game-rules.md) — §4 spawn row, §4b Rules-disabled levels
- [x] [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — playable inventory / roundabout module
- [x] This spec — acceptance criteria checked; **Status** → Done (rules TBD); **Implementation log** line
- [ ] `AGENTS.md` — N/A (no new stable preference)
- [ ] N/A — spawn refactor; rules deferred to future spec

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-26 | Centralized TMX spawn in `tiled_map_loader.dart`; rules disabled for Roundabout Basics; core rules §4b |
| 2026-06-26 | Spec normalized to completion-gate template |
