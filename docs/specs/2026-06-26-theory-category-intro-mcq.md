# Theory categories — intro + MCQ modules

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | Agent |
| **Created** | 2026-06-26 |
| **Related** | `assets/config/theory_curriculum.json` |

---

## Goal

Unlock the five non–road-sign theory categories (Best Practices, Traffic Rules, Parking, Vehicle Control, Safety Procedures) with a minimal playable path: **intro** → **MCQ** (6 text questions each). Intro images are user-supplied placeholders until bundled.

## Non-goals

- Road signs curriculum changes
- Minigames or extra difficulty tiers per category
- Replacing legacy `theory_tests_service.dart` rows (unused for navigation)

---

## Requirements

### Functional

1. Each of the five categories is selectable from Theory Test hub (not under development).
2. Category opens a module list: intro (unlocked) → MCQ (unlocked after intro viewed).
3. Intro marks module viewed on back navigation (same progress store as road-signs study modules).
4. MCQ uses 70% pass threshold via `ProgressRepository.recordTheoryAttempt`.
5. Missing intro images show placeholder with expected path.
6. Best Practices intro uses a paginated carousel (`introSlides`: image + text per scenario); MCQ unlocks after **Done** on the last slide.

### Best Practices intro slides

| Slide id | Image path |
|----------|------------|
| `seatbelt` | `assets/images/theory/intro/best_practices/seatbelt.png` |
| `mirrors` | `assets/images/theory/intro/best_practices/mirrors.png` |
| `following_distance` | `assets/images/theory/intro/best_practices/following_distance.png` |
| `stay_alert` | `assets/images/theory/intro/best_practices/stay_alert.png` |

### Config

- `assets/config/theory_curriculum.json` — categories, intro copy, modules, image paths.

---

## Technical design

| Item | Detail |
|------|--------|
| Curriculum | `lib/services/content/theory_curriculum_service.dart` |
| Models | `lib/models/theory/theory_category_curriculum.dart` |
| Questions | `lib/services/content/theory_questions_service.dart` (text-only) |
| MCQ resolver | `lib/services/content/mcq_questions_service.dart` |
| UI | `theory_category_modules_screen.dart`, `theory_intro_screen.dart`, `roadsign_mcq_screen.dart` |
| Hub | `theory_test_categories_screen.dart` → modules screen |

---

## Acceptance criteria

- [x] Five categories unlocked on theory hub
- [x] Intro + MCQ per category in JSON
- [x] 6 MCQ questions per category pool
- [x] Intro unlocks MCQ; 70% pass records completion
- [x] Placeholder when intro image missing
- [x] Spec kit updated

---

## Implementation log

- 2026-06-26: Shipped `theory_curriculum.json`, curriculum service, intro/MCQ screens, `TheoryQuestionsService`, unlocked category cards.
