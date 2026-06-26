# Module final assessments (mixed MCQ + practical)

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | Agent |
| **Created** | 2026-06-27 |
| **Related** | `assets/config/module_finals.json`, learning path `module_final` nodes |

---

## Goal

Replace computed “module check” checkpoints with **playable module tests** that mix theory (MCQ) and practical driving where the module has both. Passing a module test unlocks the next learning-path module.

## Non-goals

- Grand final as a playable exam (remains a celebration node when all module tests are passed).
- New MCQ question authoring (reuse existing pools).
- Changing lesson MCQ or driving level pass rules.

---

## Background

- [`../core-game-rules.md`](../core-game-rules.md) — §7 Learning path, §8 Theory pass threshold (70%).
- [`2026-06-26-learning-path.md`](./2026-06-26-learning-path.md) — path structure and node kinds.

---

## Requirements

### Functional

1. Each `module_final` path node opens a **module test** screen when unlocked.
2. Unlock: all `unlockRequirementIds` for that node (lessons in the module) must be complete.
3. Completion: player **passes** the module test (theory ≥70% when MCQ is included; each listed practical level passed in sequence).
4. Config per module in `assets/config/module_finals.json` (`mcqPools`, `mcqQuestionCount`, `drivingLevelIds`, `passScorePercent`).
5. Progress stored via `ProgressRepository.recordModuleFinalPassed(nodeId)` (reuses theory progress row with node id).
6. `grand_final` completes when all module-final node ids in its `unlockRequirementIds` are passed.

### UI

- Path tile label: **Module test** (flag icon).
- Module test: intro → theory section (if configured) → practical section(s) (if configured) → pass/fail result.
- No AI assistant on the module test screen (active assessment).

---

## Technical design

| Item | Detail |
|------|--------|
| Manifest | `assets/config/module_finals.json` |
| Models | `lib/models/learning/module_final_assessment.dart` |
| Service | `lib/services/content/module_finals_service.dart` |
| Screen | `lib/screens/learning/module_final_screen.dart` |
| MCQ widget | `lib/widgets/learning/module_final_mcq_panel.dart` |
| Navigation | `learning_path_navigator.dart` → `ModuleFinalScreen` |
| Progress | `learning_path_service.dart`, `ProgressRepository` |

---

## Acceptance criteria

- [x] Module final nodes open mixed assessment (not “module complete” dialog only)
- [x] Theory-only modules: MCQ-only test
- [x] Driving-heavy modules: MCQ + practical levels per config
- [x] Pass/fail persisted; path node shows done when passed
- [x] Next module unlocks only after module test passed
- [x] **Spec kit updated**

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-27 | Module finals: `module_finals.json`, `ModuleFinalScreen`, progress + path wiring; updated core-game-rules §7, learning-path spec |
