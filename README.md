# Road Rules

An interactive road safety education app built with Flutter. Road Rules helps learners study traffic laws and practice driving skills through two core modes: a Theory Test (MCQ) and an interactive Driving Test simulation.

---

## Features

### Authentication
- Email / password sign-in and account creation
- Google Sign-In
- Facebook Sign-In
- Powered by Firebase Authentication

### Theory Test (MCQ)
Test your knowledge across six topic categories, each with progressively harder tests that unlock as you advance:

| Category | Description |
|---|---|
| Road Signs | Warning, regulatory, priority, and information signs |
| Best Practices | Safe driving rules, defensive driving, and etiquette |
| Traffic Rules | Sri Lankan traffic laws, licensing, and penalties |
| Parking | Parking regulations, zones, and restrictions |
| Vehicle Control | Steering, acceleration, gear systems, and maneuvers |
| Safety Procedures | Emergency response, breakdowns, and adverse conditions |

Difficulty levels: **Easy → Medium → Hard**

### Driving Test (Interactive Simulation)
Practice driving through real-world scenarios using the Flame game engine. Choose from five driving topics, each with multiple levels:

| Topic | Description |
|---|---|
| Junctions | T-junctions, crossroads, and roundabouts |
| Road Markings | Lane markings, crossings, and zones |
| Road Signs | Warning, regulatory, and information signs |
| Emergency Situations | Braking, breakdowns, and emergencies |
| Parking | Parallel, perpendicular, and angle parking |

Controls: on-screen steering wheel, accelerator, and brake — or keyboard (Arrow keys / WASD).

### Profile
View your account information and sign out securely.

---

## Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| Flutter | SDK ^3.7.2 | Cross-platform UI framework |
| Flame | ^1.18.0 | 2D game engine for the driving simulation |
| flame_tiled | ^1.18.0 | Tiled map support |
| Firebase Core | ^3.8.1 | Firebase SDK initialization |
| Firebase Auth | ^5.3.4 | User authentication |
| Google Sign-In | ^6.2.2 | Google OAuth |
| Flutter Facebook Auth | ^7.0.0 | Facebook OAuth |
| Google Fonts | ^6.1.0 | Typography |

Custom fonts: **Inter** (UI) and **RobotoMono** (monospaced details)

---

## Project Structure

```
lib/
├── main.dart                   # App entry point, Firebase init
├── firebase_options.dart       # Firebase platform configuration
├── game/
│   └── realistic_car_game.dart # Flame game: car physics & rendering
├── game.dart                   # Car and RealisticCarGame classes
├── models/
│   ├── game_level.dart         # Level, DrivingTopic, LevelDifficulty
│   └── theory_test.dart        # TheoryTest, category enums
├── screens/
│   ├── auth_wrapper.dart       # Auth state router
│   ├── auth_screen.dart        # Sign-in screen
│   ├── sign_up_screen.dart     # Account creation screen
│   ├── menu_screen.dart        # Main menu (Play / Options / Profile / Quit)
│   ├── test_selection_screen.dart          # Choose Theory or Driving test
│   ├── theory_test_categories_screen.dart  # MCQ category list
│   ├── theory_test_selection_screen.dart   # MCQ test list within a category
│   ├── driving_topic_selection_screen.dart # Driving topic list
│   ├── level_selection_screen.dart         # Level grid for a driving topic
│   ├── game_screen.dart                    # Flame game screen
│   └── profile_screen.dart                # User profile & sign-out
├── services/
│   ├── driving_levels_service.dart # Level data and unlock logic
│   ├── theory_tests_service.dart   # MCQ test data and unlock logic
│   └── image_preloader.dart        # Background image preloading
├── theme/
│   └── swiss_theme.dart        # Swiss-style design system (colors, typography)
└── utils/
    └── app_fonts.dart          # Font helper utilities
```

---

## Getting Started

### Prerequisites
- [Flutter](https://docs.flutter.dev/get-started/install) SDK ^3.7.2
- A Firebase project with Authentication enabled (Email/Password, Google, Facebook)
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) placed in their respective platform folders

### Run the app

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Build

```bash
# Android
flutter build apk

# iOS
flutter build ios

# Web
flutter build web
```

---

## Supported Platforms

- Android (min SDK 21)
- iOS
- Web
- Windows
- macOS
- Linux
