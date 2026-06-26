# Unified level briefing carousel

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | Agent |
| **Created** | 2026-06-26 |
| **Related** | All rules-enabled practical levels |

---

## Goal

Give every practical driving level a **consistent pre-level briefing** — paginated slides with Skip / Back / Next / Start Level — instead of mixed text-wall dialogs, ambulance-only carousel, or no briefing at all.

## Non-goals

- First-attempt-only briefing persistence (future enhancement).
- Briefings for rules-disabled levels (e.g. Roundabout Basics).
- Briefings for under-development levels without a map asset.

---

## Background

- Read [`../core-game-rules.md`](../core-game-rules.md) — §4b rules-disabled levels, §7 level catalog.
- Prior behaviour: `level_briefing.dart` used a text `AlertDialog` for three scenarios and a separate ambulance carousel; most junction/marking levels had no briefing.
- Session lifecycle: radio and engine start remain gated until briefing dismiss (`game_screen.dart`).

---

## Requirements

### Functional

1. One shared carousel UI (`LevelBriefingDialog`) for all briefings.
2. Briefing content resolved via registry: `level.id` → `scenarioId` → default (name + description).
3. Show briefing for levels with `enableDrivingRules: true` and a non-empty `mapAsset`.
4. Migrate ambulance, zebra, stop/yield, and adverse-weather copy into slide lists.
5. Add scenario briefings for junction and lane-marking levels; level-id override for junction box.

### Session / lifecycle

- Engine paused until briefing dismissed; `MusicService.beginDrivingLesson` after dismiss (unchanged).
- Skip closes briefing immediately (same as ambulance carousel).

---

## Technical design

| Item | Detail |
|------|--------|
| Model | `lib/models/driving/level_briefing.dart` |
| Registry | `lib/services/content/level_briefing_registry.dart` |
| Dialog | `lib/widgets/driving/level_briefing_dialog.dart` |
| Entry | `lib/widgets/driving/level_briefing.dart` |
| Removed | `ambulance_briefing_carousel.dart` |

---

## Acceptance criteria

- [x] All rules-enabled levels with a map show the carousel briefing before play.
- [x] Rules-disabled levels (roundabout basics) skip briefing.
- [x] Ambulance retains multi-slide content in registry.
- [x] Zebra, stop/yield, weather use carousel slides (not text wall).
- [x] Default 1-slide briefing for levels without custom registry entry.
- [x] **Spec kit updated**

---

## Test plan

### Manual

1. Start Left Turn — carousel with junction slides; Start Level resumes engine + radio.
2. Start Ambulance — multi-slide briefing; Skip works.
3. Start Roundabout Basics — no briefing; engine starts immediately.
4. Start a level with only default briefing — shows name + description slide.

---

## Spec kit updates

- [x] [`../core-game-rules.md`](../core-game-rules.md) — §9 Level briefings
- [x] [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — briefing DoD + technical reference
- [x] This spec — Status Done; implementation log
- [x] [`README.md`](./README.md) — index row

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-26 | Unified carousel + registry; removed ambulance-only dialog and text-wall briefings |
