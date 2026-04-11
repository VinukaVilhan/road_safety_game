# Technology Used in Development

This document describes the frameworks, tools, and technologies used to build **Road Rules** (road safety education: theory tests and driving simulation). A **short form version (≤500 words)** is provided first for innovation or grant submissions; the **appendix** lists packages for engineering reference.

---

## Short form (copy for “Technology used” — ≤500 words)

Road Rules is built with **Flutter** and the **Dart SDK (^3.7.2)**, using **Material Design** for cross-platform UI on Android, iOS, web, Windows, macOS, and Linux. The app follows a **custom Swiss-style design system** (themed colors and typography) with bundled variable fonts (**Inter**, **Roboto Mono**, **Pixelify Sans**) and **Google Fonts** for flexible typography where needed.

The **interactive driving simulation** uses the **Flame** 2D game engine (^1.18.0), with **flame_tiled** for **Tiled** map workflows and **flame_audio** for game-oriented audio. Supporting assets include raster images, **SVG** road signs via **flutter_svg**, tilesets, and packaged **audio** (including **just_audio** for broader playback control). An on-screen **steering wheel and pedals** (and optional keyboard input) drive the vehicle in **Flame**-hosted game screens.

**User accounts and cloud data** rely on **Firebase**: **firebase_core** for initialization, **firebase_auth** for identity, and **cloud_firestore** for remote persistence and sync-oriented features. Social sign-in uses **google_sign_in** and **flutter_facebook_auth** alongside email/password, with platform configuration via **firebase_options** and native Firebase config files.

**Local-first storage** uses **Isar** (with **isar_flutter_libs** and **isar_generator** / **build_runner** for code generation) for fast on-device schemas and offline-friendly behavior. **shared_preferences** stores lightweight settings; **path_provider** and **uuid** support file paths and identifiers; **connectivity_plus** informs network-aware flows; **sync** layers coordinate local and remote state.

**AI-assisted learning** integrates **Google’s Generative AI SDK for Dart** (**google_generative_ai**) for an in-app assistant experience (context-aware help grounded in app configuration). **url_launcher** opens external links where appropriate.

**Quality and delivery tooling** includes **flutter_lints** for static analysis, **flutter_test** for automated tests, and **flutter_launcher_icons** for consistent app icons across platforms. **file_picker** and **permission_handler** support optional user media (e.g., custom music folders) with platform-appropriate permissions.

Development is done in **Dart/Flutter** with **VS Code** or **Android Studio**-class IDEs, **Flutter CLI** for `run`/`build`, and **pub** for dependency management. Together, these choices prioritize a **single codebase**, **offline-capable local data**, **managed cloud auth and sync**, **accessible educational UI**, and a **performant mini-game loop** for hands-on road safety practice.

---

## Appendix — key packages (engineering reference)

| Area | Packages |
|------|----------|
| Core UI | `flutter`, Material Design, `cupertino_icons` |
| Game | `flame`, `flame_tiled`, `flame_audio` |
| Auth & cloud | `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `flutter_facebook_auth` |
| Local DB | `isar`, `isar_flutter_libs`, `isar_generator` (dev), `build_runner` (dev) |
| Audio & media | `just_audio`, `flame_audio`, `file_picker`, `permission_handler` |
| Typography & graphics | `google_fonts`, `flutter_svg`, bundled `.ttf` fonts |
| Platform & utilities | `path_provider`, `shared_preferences`, `connectivity_plus`, `uuid`, `url_launcher` |
| AI | `google_generative_ai` |
| Dev experience | `flutter_lints`, `flutter_test`, `flutter_launcher_icons` |

---

## Word count note

The **Short form** section above is written to stay within **500 words** for typical submission fields. If a portal counts differently, trim the last paragraph or the AI/optional-media sentences first.
