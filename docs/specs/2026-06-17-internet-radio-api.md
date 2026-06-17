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

### UI

- `RadioTunerSheet` — search, station list, now playing
- `game_screen.dart` — subtitle: "Stream stations in-app via API"

---

## Acceptance criteria

- [x] Stations load from API on open
- [x] Search filters stations via API
- [x] Playback uses `MusicService` / `just_audio` only
- [x] No `openFmRadio` platform channel
- [x] Radio stops on level pass/fail and when leaving game
- [x] Radio blocked until briefing ends; resumes on retry
- [ ] Manual playtest: pick station, hear audio, pause/stop

---

## Spec kit updates

- [x] This spec — Status Done
- [ ] `core-game-rules.md` — N/A (non-gameplay)
- [ ] `AGENTS.md` — N/A

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-17 | Driving-lesson session gating: `beginDrivingLesson` / `endDrivingLesson` in `MusicService` + `GameScreen` lifecycle |
