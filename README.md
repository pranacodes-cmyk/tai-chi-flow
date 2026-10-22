# TaiChi Flow — Android app (Flutter)

Tai Chi, Qigong, chair yoga, mindful walking and meditation. This Flutter app is the
production Android client; the web project at the repository root is its pixel-matched
interactive prototype.

## Build

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # Play Store bundle
```

CI (this repo): `.github/workflows/build.yml` builds a debug APK on every push to `main` or manual run (artifact `enso-debug-apk`). In the Lovable monorepo, `.github/workflows/android.yml` builds the APK + AAB on every push to `main`
touching `mobile/` and uploads them as the `enso-android` artifact.

### Release signing

Without signing secrets, release builds are signed with the debug key (installable,
not Play-uploadable). To sign for the Play Store add these GitHub secrets:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
`ANDROID_STORE_PASSWORD` — or locally create `android/key.properties`:

```
storeFile=release.jks
storePassword=…
keyAlias=…
keyPassword=…
```

## Structure

| Path | What |
| --- | --- |
| `lib/theme/` | Design tokens (colors, gradients, shadows, type) — mirror `src/styles.css` |
| `lib/data/` | Content models + loader for `assets/data/content.json` |
| `lib/logic/logic.dart` | Business rules — 1:1 with `src/lib/logic.ts` |
| `lib/state/app_state.dart` | Persisted state — mirrors `src/lib/store.ts` |
| `lib/services/` | Audio/voice, reminders, purchases (simulated until RevenueCat) |
| `lib/widgets/` | Shared UI (buttons, rings, sheets, tab bar, ruler, breath orb…) |
| `lib/screens/` | One file per screen, same names as the web routes |

Shared assets (`assets/data`, `assets/images`, `assets/audio`) are generated at the
repo root: `bun scripts/generate-content.ts`, `python3 scripts/generate-audio.py`,
`bash scripts/sync-mobile-assets.sh`.
