# In-app internet radio (API streaming)

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | Agent |
| **Created** | 2026-06-17 |
| **Related** | Driving HUD — Music → Radio |

---

## Goal

Replace the phone FM app launcher with in-app internet radio: stations fetched from a public API and played via `just_audio` inside the game.

## Non-goals

- Hardware FM tuning on the device
- Spotify or local music folder changes
- Gameplay / zone rules

---

## Background

- Prior behaviour opened OEM FM apps via Android `MethodChannel` — not true in-app radio.
- `MusicService.playUrl` already supported stream URLs; radio UI did not use it.

---

## Requirements

### Functional

1. Radio sheet loads stations from Radio Browser API (`de1.api.radio-browser.info`).
2. User can search stations by name.
3. Tapping a station plays the stream in-app (no external app).
4. Now-playing bar shows play/pause/stop.
5. Remove FM app launcher (`FmRadioService`, Android FM package queries).
6. Radio plays **only during an active driving lesson** — not during briefing, not after pass/fail.
7. Playback **stops automatically** when the lesson ends (pass, fail, quit, or leave `GameScreen`).
8. Retry after fail re-enables radio for the new attempt.
9. Radio volume capped below vehicle idle / reverse / accelerate SFX (`DrivingAudioLevels.radioMaxDuringLesson`).

### Session / lifecycle

- Radio gated to active driving lesson via `MusicService.beginDrivingLesson` / `endDrivingLesson`.
- Blocked during briefing; stops on pass, fail, quit, or leave `GameScreen`.
- Retry after fail re-enables radio for the new attempt.

---

## Technical design

### Flutter / Flame

| Item | Detail |
|------|--------|
| API client | `lib/services/audio/radio_api_service.dart` — Radio Browser API |
| Playback | `MusicService.playUrl` / `just_audio`; volume capped via `driving_audio_levels.dart` |
| UI | `RadioTunerSheet`; `game_screen.dart` — "Stream stations in-app via API" |
| Removed | `FmRadioService`, Android FM `MethodChannel` |

---

## Acceptance criteria

- [x] Stations load from API on open
- [x] Search filters stations via API
- [x] Playback uses `MusicService` / `just_audio` only
- [x] No `openFmRadio` platform channel
- [x] Radio stops on level pass/fail and when leaving game
- [x] Radio blocked until briefing ends; resumes on retry
- [x] Radio volume stays below car idle / reverse / accelerate SFX during lesson
- [ ] Manual playtest: pick station, hear audio, pause/stop
- [x] **Spec kit updated** (same task as code)

---

## Test plan

### Manual

1. Start a driving level; open Radio after briefing ends — stations load.
2. Search and play a station — audio in-app, no external FM app.
3. Pass or fail level — radio stops automatically.
4. Leave `GameScreen` — radio stops.
5. Retry after fail — radio available again for new attempt.

---

## Spec kit updates (required when shipping)

Run the **agent completion gate** in [`.cursor/rules/spec-driven.mdc`](../../.cursor/rules/spec-driven.mdc).

- [ ] [`../core-game-rules.md`](../core-game-rules.md) — N/A (non-gameplay feature)
- [x] This spec — acceptance criteria checked; **Status** → Done; **Implementation log** line
- [x] `AGENTS.md` — radio lifecycle + `MusicService` gating bullet
- [x] N/A — audio/session feature; no zone rule change

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-17 | In-app Radio Browser API + `just_audio`; removed FM launcher |
| 2026-06-17 | Driving-lesson session gating: `beginDrivingLesson` / `endDrivingLesson` in `MusicService` + `GameScreen` lifecycle |
| 2026-06-26 | Spec normalized to completion-gate template |
| 2026-06-26 | Radio mix cap: `DrivingAudioLevels.radioMaxDuringLesson` (85% of reverse loop vol) |
