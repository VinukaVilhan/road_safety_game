# Road Safety Game — core game rules

Canonical gameplay rules agents and specs must respect. **Do not contradict these** when implementing levels unless a dated spec explicitly changes a rule.

**Spec kit:** [`README.md`](./README.md) · workflow [`.cursor/rules/spec-driven.mdc`](../.cursor/rules/spec-driven.mdc) · meta spec [`specs/2026-06-26-spec-driven-kit.md`](./specs/2026-06-26-spec-driven-kit.md)

Per-feature work: copy [`specs/_template.md`](./specs/_template.md) and cite affected sections below in the spec **Background**.

---

## 1. Map format (Tiled / TMX)

| Rule | Detail |
|------|--------|
| **Map assets** | `assets/tiles/*.tmx` loaded by `RealisticCarGame` via Flame Tiled |
| **Collision** | Object layer `Obstacles_Layer` or class `Collision_Box` — axis-aligned rects only |
| **Spawn** | Layer `Spawn_Layer` / class `Spawn_Point` — point object |
| **Zone classes** | Object `class`, `type`, or `name` (fallback order) — see §2 |

**Code:** `lib/game/driving_game.dart` (`_setupRoad`)

---

## 2. Driving zone types

| Tiled class / type | Engine kind | Behaviour |
|--------------------|-------------|-----------|
| `Zone_Check`, `Zone_Approach`, `Zone_SpeedLimit` (on `Zone_Check` layer) | `zone_check` | Yellow approach; `step_id`, `max_speed` / `speed_limit` |
| `Zig_Zag` | `zig_zag` | Grey wait zone; `wait_time` (seconds); road-crossing Park + countdown |
| `Zone_Finish` | `zone_finish` | Green finish; pass when prior `step_id` completed |
| `Zone_Fail_WT`, `Wrong_Turn_Layer` | `zone_fail_wt` | **Immediate level fail** on entry — wheel contact for thin strips |
| `Zone_Fail_IT` | `zone_fail_it` | Immediate fail — oncoming traffic |
| `Wrong_Layer` | `wrong_layer` | Penalty + fail (dashed markings maps) |

Optional object/layer property: `fail_message` (custom fail text).

**Code:** `_zoneKindForScenario`, `_handleZoneEntry`, `_carContactsDrivingZone`

---

## 3. Road-crossing levels (`road-crossing.tmx`)

| Rule | Detail |
|------|--------|
| **Maps** | `road_crossing.tmx` — scenarios `markings_zebra_crossing`, `markings_stop_yield` |
| **Approach** | Enter yellow `Zone_Check` — speed capped at `max_speed` / `speed_limit` (60 on `road_crossing.tmx`) |
| **Spawn sign** | Entering `Spawn_Sign` layer shows pedestrian-crossing sign HUD (bottom-left, `pedestrian_crossing.jpeg`) with live distance (metres) to the nearest `Zig_Zag` zone |
| **Zebra wait** | All wheels inside **one** grey `Zig_Zag` on your side + full stop in gear; **must not touch both zig-zags on the same horizontal row** (lane straddle) |
| **Wrong turn** | `Zone_Fail_WT` past the stop line — **ends level immediately** with fail dialog |
| **Finish** | Green `Zone_Finish` after step 1 (zebra wait) satisfied |
| **Fail detection** | Any wheel inside `Zone_Fail_WT` (zone height may be thinner than the car) |

**Code:** `_updateRoadCrossingParkCountdown`, `_isRoadCrossingMap`

---

## 4. Junction / turn levels

| Rule | Detail |
|------|--------|
| **Maps** | `t_junction_*.tmx`, `cross_junction.tmx`, `junction_box.tmx`, `roundabout_junction.tmx` |
| **Spawn** | Central loader: `Spawn_Layer` / `Spawn_Point` → car + camera via `_applyPlayerSpawnToWorld` (`lib/game/map/tiled_map_loader.dart`) |
| **Approach** | Yellow zone + correct turn signal |
| **Turn** | Purple mid-turn validation (`Zone_MidTurn` / `expected_signal`) |
| **Finish** | Green zone after steps completed |
| **Wrong turn / IT** | `Zone_Fail_WT` / `Zone_Fail_IT` — immediate fail |
| **Roundabout Basics** | `enableDrivingRules: false` — map + spawn + collision only until rules are defined in a spec |

---

## 4b. Rules-disabled levels

| Rule | Detail |
|------|--------|
| **Flag** | `GameLevel.enableDrivingRules` → `RealisticCarGame.drivingRulesEnabled` |
| **Behaviour** | TMX zones not loaded; no pass/fail from zone entry, mid-turn, junction box, or speed caps |
| **Current** | `junctions_roundabout_basics` (`roundabout_basics`) |

**Code:** `lib/game/map/tiled_map_loader.dart`, `_setupRoad` in `driving_game.dart`

---

## 5. Scoring & reports

| Rule | Detail |
|------|--------|
| **Pass** | `onTestPassed` when finish zone entered with steps satisfied |
| **Fail** | `onTestFailed(message)` — whistle SFX; message shown in summary |
| **Road-crossing rubric** | Approach zone, zebra wait, finish, obstacle bumps — instant fails (wrong turn) use `failureMessage` not checklist rows |

**Code:** `lib/services/progress/last_driving_report_service.dart`, `lib/screens/game_screen.dart`

---

## 6. Emergency ambulance scenario

| Rule | Detail |
|------|--------|
| **Scenario id** | `emergency_ambulance` — separate checkpoint / pull-over rules |
| **Zone rules** | Standard driving zones disabled; ambulance-specific logic only |

**Code:** `_isEmergencyAmbulanceScenario`

---

## 8. Adverse weather scenario

| Rule | Detail |
|------|--------|
| **Scenario id** | `emergency_weather` — rain visuals + wet-road physics on any linked map |
| **Map** | `cross_junction.tmx` (standard junction zones; same pass flow as cross junction basics) |
| **Rain visuals** | Viewport-space vertical streaks via `RainViewportOverlay`; periodic lightning flash via `ThunderFlashOverlay` (~32–58s random gap; ~35% double-flash); world-space low-beam cones on the player car via `CarWeatherHeadlightsPainter` |
| **Weather audio** | Looping `rain_ambience.mp3`; one-shot `thunder_clap.mp3` per lightning event (once even for double-flash) |
| **Wet grip** | Friction ×0.55, braking ×0.6, steering grip ×0.72; slight lateral slide on sharp steer at speed |
| **Speed cap** | ~72 world units/sec while raining; exceeding records one non-fatal penalty: *Driving too fast for wet road conditions* |
| **Unlock** | Open by default (first level in topic **Weather Conditions** on Driving test main menu) |

**Code:** `lib/game/scenarios/emergency_weather.dart`, `lib/game/entities/car_facing.dart` (`CarFacing` / `CarZones`), `Car` weather multipliers, `level_briefing_registry.dart`

---

## 7. Level curriculum & progress

Full design (unlock graph, definition of done for new levels): [`specs/2026-06-26-level-system-design.md`](./specs/2026-06-26-level-system-design.md).

| Rule | Detail |
|------|--------|
| **Catalog** | All practical levels are `GameLevel` rows in `lib/services/content/driving_levels_service.dart` — not procedural |
| **Map link** | `mapAsset` → `assets/tiles/*.tmx`; optional `scenarioId` for shared maps or special logic |
| **Unlock** | `unlockRequirementIds` must all be completed; if empty, `isUnlocked` default applies. Under-development levels stay locked in UI regardless |
| **Completion** | Pass = finish zone with steps satisfied → `LevelProgressService.markLevelCompleted` (signed-in users only). Dashed markings: finish can unlock even when penalties block report pass |
| **Reports** | `LastDrivingReportService` stores per-attempt diagnostics (score, rubric, mistakes) — separate from unlock state |
| **Default speed** | Engine `roadSpeed` defaults to 200 in `RealisticCarGame` — not tiered by level label |
| **Theory pass threshold** | 70% in `ProgressRepository` — applies to theory tests only, not practical driving |

Practical levels have **no** Easy/Medium/Hard tier. Progression is module order + unlock chain. Theory uses `TestDifficulty` separately.

**Learning path (PLAY):** One consolidated curriculum map replaces the Theory/Driving fork. Manifest: `assets/config/learning_path.json`. Per module: theory (intro + MCQ) → practical levels → module checkpoint; grand final when all module checkpoints are done. Path unlock uses `unlockRequirementIds` on path nodes; completion reads existing theory and driving progress stores (no duplicate lesson state). Under-development driving levels stay locked on the path. Spec: [`specs/2026-06-26-learning-path.md`](./specs/2026-06-26-learning-path.md).

**Code:** `level_selection_screen.dart`, `game_screen.dart`, `level_progress_service.dart`, `last_driving_report_service.dart`, `driving_game.dart`, `learning_path_screen.dart`, `learning_path_service.dart`

---

## 8. Theory test categories (intro + MCQ)

| Rule | Detail |
|------|--------|
| **Hub** | Six categories on Theory Test screen; Road Signs uses `road_signs_curriculum.json`; other five use `theory_curriculum.json` |
| **Module kinds** | `intro` (reference sheet + image) then `mcq` (text-only for these five categories) |
| **Unlock** | View intro module → MCQ unlocks; MCQ pass (≥70%) stored by module/test id |
| **Intro images** | `assets/images/theory/intro/<category_id>/` — carousel (`introSlides` in JSON): one image per scenario; all five theory categories use this pattern |
| **Questions** | `TheoryQuestionsService` pools; shared MCQ UI via `RoadSignMcqScreen` + `McqQuestionsService` |

Spec: [`specs/2026-06-26-theory-category-intro-mcq.md`](./specs/2026-06-26-theory-category-intro-mcq.md)

**Code:** `theory_test_categories_screen.dart`, `theory_category_modules_screen.dart`, `theory_intro_screen.dart`, `theory_curriculum_service.dart`

---

## 9. Level briefings

| Rule | Detail |
|------|--------|
| **When shown** | Start of every practical level with `enableDrivingRules: true` and a `mapAsset` — engine paused until dismissed |
| **UI** | Paginated carousel: headline, titled slides, dots, Back / Next / **Start Level**, optional **Skip** |
| **Content lookup** | `level.id` override → `scenarioId` → default slide (`name` + `description` + zone reminder) |
| **Registry** | `lib/services/content/level_briefing_registry.dart` |
| **Skipped** | Rules-disabled levels (§4b); levels without a map asset |
| **Session** | Radio blocked until briefing ends (`MusicService.beginDrivingLesson` after dismiss). Gearbox and accelerator blocked for **4 seconds** after level start (all levels, including Retry); brake and steering stay enabled. All lesson audio (engine, rain, ambulance siren) stops via `endLessonAudio()` on quit, pass/fail, or leaving `GameScreen`. |

Slide shape: **Mission** → **Zones / rules** → **Pass/fail** (2–4 slides for custom scenarios; 1 slide for default).

**Code:** `lib/widgets/driving/level_briefing.dart`, `level_briefing_dialog.dart`, `game_screen.dart`

Spec: [`specs/2026-06-26-level-briefing-carousel.md`](./specs/2026-06-26-level-briefing-carousel.md)

---

*Last updated: 2026-06-26 — driving controls gated until engine-start SFX completes.*
