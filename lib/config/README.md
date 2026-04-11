# AI assistant (Gemini) configuration

The assistant uses the `google_generative_ai` package and a **Gemini API key** from either a bundled JSON file or compile-time defines.

## Option A — JSON file (simplest for daily `flutter run`)

Edit **`assets/config/developer_env.json`** in the repo and set `GEMINI_API_KEY` to your key:

```json
{
  "GEMINI_API_KEY": "your_key_here"
}
```

Hot restart / rebuild after changing the file. Avoid committing real keys; use API key restrictions in Google AI Studio / Cloud Console, or prefer Option B for release builds.

## Option B — `dart-define` (CI / release)

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

Defines override the JSON file when non-empty.

You can also keep defines in a local JSON file (not committed) and point Flutter at it:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

Example `dart_defines.json`:

```json
{
  "GEMINI_API_KEY": "your_key_here"
}
```

Release / CI builds should inject the key from your secret store (never commit production keys).

## Get a key

Create a key in [Google AI Studio](https://aistudio.google.com/apikey) (or enable the Generative Language API in Google Cloud).

## Cloudinary (driving screenshots)

Add to the same JSON (or use `dart-define`):

- `CLOUDINARY_CLOUD_NAME` — dashboard cloud name
- `CLOUDINARY_UPLOAD_PRESET` — **unsigned** preset (restrict format/size in the Cloudinary UI; do not put `api_secret` in the app)

The app stores the returned `https` URL in Firestore on the driving report as `screenshotUrl`. If your preset allows it, you can extend `CloudinaryUploadService` to pass `folder` / `public_id` for tidier asset paths.

## Gitignored local overrides (optional)

If you add extra secret files, list them in the project root `.gitignore` so they are never committed.
