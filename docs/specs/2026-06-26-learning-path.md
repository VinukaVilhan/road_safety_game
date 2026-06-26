# Consolidated learning path (theory → driving → module final)

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | Agent |
| **Created** | 2026-06-26 |
| **Related** | `assets/config/learning_path.json`, PLAY menu entry |

---

## Goal

Replace the Theory Test / Driving Test fork with one **landscape learning path**: per themed module, players complete theory (intro + MCQ), then practical driving levels where available, then a **module test** (mixed MCQ + practical) before the next module. A **grand final** node appears when all module tests are complete.

## Non-goals

- Merging `theory_curriculum.json` and `driving_levels_service.dart` into one catalog.
- New lesson content (junctions theory, parking practical, etc.) — gaps stay `underDevelopment` or omitted.
- Removing legacy `TestSelectionScreen` / topic pickers (still reachable indirectly if linked elsewhere).

---

## Background

- [`../core-game-rules.md`](../core-game-rules.md) — §7 Level curriculum, §8 Theory categories.
- [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — driving unlock graph.
- Path manifest references existing theory module ids, road-signs module ids, and `GameLevel.id` values.

---

## Requirements

### Functional

1. PLAY from home opens **Learning Path** (not Theory/Driving split).
2. Path modules are separated visually; nodes unlock in manifest order with cross-module gates via `unlockRequirementIds`.
3. Node kinds: `theory_intro`, `theory_mcq`, `road_signs_intro`, `road_signs_mcq`, `road_signs_minigame`, `driving_level`, `module_final`, `grand_final`.
4. Completion reads existing progress (theory MCQ pass, intro viewed, driving level complete) — no duplicate lesson state.
5. `module_final` completes when the player **passes** the module test (`module_finals.json`). `grand_final` completes when all module tests are passed.
6. Under-development driving nodes stay locked (same ids as level selection).

### UI

- Landscape scrollable path; `BrowseScreenHeader` + assistant on browse screen.
- Locked / current / done states per node.

---

## Technical design

| Item | Detail |
|------|--------|
| Manifest | `assets/config/learning_path.json` |
| Models | `lib/models/learning/learning_path.dart` |
| Service | `lib/services/content/learning_path_service.dart` |
| Navigation | `lib/services/learning/learning_path_navigator.dart` |
| UI | `lib/screens/learning/learning_path_screen.dart`, `lib/widgets/learning/path_node_tile.dart` |
| Entry | `menu_screen.dart` → `LearningPathScreen` |

---

## Acceptance criteria

- [x] PLAY opens consolidated learning path
- [x] Modules show theory → driving → final ordering where content exists
- [x] Unlock uses path `unlockRequirementIds` + existing progress stores
- [x] Tapping nodes opens existing intro / MCQ / minigame / `GameScreen` flows
- [x] Under-development levels locked on path
- [x] Tapping `module_final` opens mixed MCQ + practical module test
- [x] **Spec kit updated**

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-26 | Initial learning path: manifest, service, screen, menu wire; updated core-game-rules §7/§10, level-system-design |
| 2026-06-27 | Module tests replace computed checkpoints — `module_finals.json`, `ModuleFinalScreen`; see `2026-06-27-module-final-assessments.md` |
