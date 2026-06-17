# Road Safety Game — core game rules

Canonical gameplay rules agents and specs must respect. **Do not contradict these** when implementing levels unless a dated spec explicitly changes a rule.

Per-feature work: copy [`specs/_template.md`](./specs/_template.md) and cite affected sections below in the spec **Background**.

---

## 1. Map format (Tiled / TMX)

| Rule | Detail |
|------|--------|
| **Map assets** | `assets/tiles/*.tmx` loaded by `RealisticCarGame` via Flame Tiled |
| **Collision** | Object layer `Obstacles_Layer` or class `Collision_Box` — axis-aligned rects only |
| **Spawn** | Layer `Spawn_Layer` / class `Spawn_Point` — point object |
| **Zone classes** | Object `class`, `type`, or `name` (fallback order) — see §2 |

**Code:** `lib/game/realistic_car_game.dart` (`_setupRoad`)

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
| **Maps** | `road-crossing.tmx` — scenarios `markings_zebra_crossing`, `markings_stop_yield` |
| **Approach** | Enter yellow `Zone_Check` — speed capped at `max_speed` / `speed_limit` (60 on `road-crossing.tmx`) |
| **Spawn sign** | Entering `Spawn_Sign` layer shows pedestrian-crossing road sign HUD (bottom-left) |
| **Zebra wait** | All wheels inside **one** grey `Zig_Zag` on your side + full stop in gear; **must not touch both zig-zags on the same horizontal row** (lane straddle) |
| **Wrong turn** | `Zone_Fail_WT` past the stop line — **ends level immediately** with fail dialog |
| **Finish** | Green `Zone_Finish` after step 1 (zebra wait) satisfied |
| **Fail detection** | Any wheel inside `Zone_Fail_WT` (zone height may be thinner than the car) |

**Code:** `_updateRoadCrossingParkCountdown`, `_isRoadCrossingMap`

---

## 4. Junction / turn levels

| Rule | Detail |
|------|--------|
| **Approach** | Yellow zone + correct turn signal |
| **Turn** | Purple mid-turn validation (`Zone_MidTurn` / `expected_signal`) |
| **Finish** | Green zone after steps completed |
| **Wrong turn / IT** | `Zone_Fail_WT` / `Zone_Fail_IT` — immediate fail |

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

*Last updated: 2026-06-17 — road-crossing `Zone_Fail_WT` wheel contact + spec kit.*
