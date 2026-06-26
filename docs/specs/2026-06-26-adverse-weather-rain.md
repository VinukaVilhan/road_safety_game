# Adverse weather — rain particles & wet-road physics

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | Agent |
| **Created** | 2026-06-26 |
| **Related** | Level `emergency_weather`, map `cross_junction.tmx` |

---

## Goal

Teach safe driving in rain: visible downpour, reduced grip, longer braking, and a wet-road speed limit — using performant Flame particles on the camera viewport.

## Non-goals

- Ground splash particles (phase 2).
- New TMX map (reuses cross junction).
- Changing ambulance or dashed-markings scenarios.

---

## Background

- Canonical zones: [`../core-game-rules.md`](../core-game-rules.md) §2, §8 (adverse weather).
- Level curriculum / unlock: [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — `emergency_weather` unlock chain.
- Cross junction pass flow matches `cross_junction_basics`.
- Top-down camera: rain must render on `camera.viewport`, not `world`.

---

## Requirements

### Functional

1. When `scenarioId == emergency_weather`, show diagonal rain streaks, a light visibility dim overlay, and low-beam headlight cones in front of the player car.
2. Car friction, braking, and steering grip are reduced; sharp steering at speed adds slight slide.
3. Speed above ~72 world units/sec is clamped and records one penalty.
4. Looping rain ambience and one thunder clap per lightning event (double-flash still uses one clap).
5. Level is open by default in Driving test → **Weather Conditions** (no cross-junction prerequisite); briefing explains wet-road rules.

### Maps / zones

| Zone class | Expected behaviour |
|------------|-------------------|
| Standard cross-junction zones | Same as `cross_junction_basics` |

### Scoring / UI

- Wet-speed penalty appears in attempt report penalties list.
- Level briefing text in `level_briefing.dart`.

---

## Technical design

### Flutter / Flame

| Item | Detail |
|------|--------|
| Rain overlay | `lib/game/effects/rain_viewport_overlay.dart` — `ParticleSystemComponent` + cycling custom `Particle` (~130 drops) |
| Headlights | `lib/game/effects/car_headlights.dart` — warm cone beams + lens highlights on [Car] when `weatherHeadlightsEnabled` |
| Scenario logic | `lib/game/scenarios/emergency_weather.dart` |
| Physics | `lib/game/entities/car.dart` reads `weatherFrictionMultiplier`, `weatherBrakeMultiplier`, `weatherSteerGripMultiplier` |
| Level row | `driving_levels_service.dart` — `mapAsset: cross_junction.tmx`, `scenarioId: emergency_weather` |
| Weather audio | `lib/game/audio/weather_sfx.dart` — `rain_ambience.mp3` loop, `thunder_clap.mp3` once per strike |

---

## Acceptance criteria

- [x] Rain visible in landscape on `emergency_weather`; streaks are diagonal, not vertical scratches.
- [x] Low-beam headlight cones visible in front of the car during adverse weather.
- [x] Braking and steering feel slipperier than dry cross junction.
- [x] Exceeding wet speed cap records penalty once per attempt.
- [x] Level playable when `junctions_cross_basics` is completed.
- [x] Spec kit updated (same task as code).

---

## Test plan

### Manual

1. Complete Cross Junction Basics, then open Driving test → Weather Conditions → Adverse Weather.
2. Read briefing, start level — confirm rain + dim overlay.
3. Brake from speed — note longer stop distance vs dry junction.
4. Hold max throttle — confirm speed clamp and penalty in report.
5. Complete junction normally — confirm pass flow unchanged.

---

## Spec kit updates (required when shipping)

Run the **agent completion gate** in [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc).

- [x] [`../core-game-rules.md`](../core-game-rules.md) — §8 Adverse weather scenario
- [x] [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md) — unlock graph (`emergency_weather`)
- [x] This spec — acceptance criteria checked; **Status** → Done; **Implementation log** line
- [ ] `AGENTS.md` — N/A (no new stable preference)
- [ ] N/A — gameplay feature; core rules updated

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-26 | Rain overlay, wet physics, level row; core rules §8; spec kit |
| 2026-06-26 | Moved level from Emergency Vehicles to Junctions → Cross Junction; unlock after `junctions_cross_basics` |
| 2026-06-26 | New Driving test topic **Weather Conditions** on main menu |
| 2026-06-26 | Thunder: longer random gaps (~32–58s); clearer double-flash with dark gap between strikes |
| 2026-06-26 | Weather SFX: `rain_ambience.mp3` loop + `thunder_clap.mp3` once per strike; asset filenames standardized (snake_case) |
| 2026-06-26 | Rain audio: `ensureRainLoop` on viewport mount and game resume; volume via `DrivingAudioLevels.rainAmbience` |
| 2026-06-26 | Unlock fix: `emergency_weather` open by default — no `junctions_cross_basics` prerequisite |
| 2026-06-26 | Rain audio: `invalidate()` on lesson end + `PopScope` on `GameScreen` — stops loop on back/quit |
| 2026-06-26 | Rain audio: app-wide `WeatherSfxService` singleton; `endLesson()` on back/route pop (fixed player id) |
| 2026-06-26 | Weather headlights: `CarWeatherHeadlightsPainter` — warm cones + lens glow on player car |
