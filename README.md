# Field App — Lab 4: Sync

Rebeca Alexandra Pestritu — implementation in Expo and Flutter.

Firebase project: **field-app-rebeca-sync**. Optional step 11: **road B**, the
Firebase Local Emulator Suite, without enabling billing. Authentication and
Firestore also work against the real Firebase project on the free plan.

This implementation continues the tested `week-3` version in this repository.
The repository interfaces, Firebase adapters and security rules are adapted from
the course's [Lab 4 reference](https://github.com/dragospaulpop/field-app/tree/week-4).
The existing Lab 3 screens, camera error handling, GPS, keyboard behavior and
local persistence have been retained and integrated with sync.

## Behavior

- Email/password sign-in, account creation, readable errors and sign-out.
- Persistent Firebase sessions on web and Android.
- A live query limited to pins assigned to the signed-in user's UID.
- SQLite is the screen's data source; an office snapshot updates synced rows and
  removes reassigned synced pins without overwriting an unsent survey.
- Submitted surveys enter an outbox. Push runs after Submit, on app resume,
  when connectivity returns, and on **Sync now**.
- Stable survey document IDs make retries idempotent. A refusal remains visible
  alongside the locally saved survey.
- Development-only **Seed my pins**, cloud count and outbox status.
- Optional photo uploads to Storage, with upload status and errors on each row.

New buildings added in the field remain local/pending this week; publication of
new buildings is left to the next lab, as in the course tutorial.

## Configure a fresh checkout

Use your own Firebase project or access to this project's console. Enable
Email/Password in Authentication and create Firestore in production mode.

```powershell
firebase.cmd login
firebase.cmd deploy --only firestore,auth --project field-app-rebeca-sync

Set-Location expo
bun install
Copy-Item .env.example .env
# Fill .env from the Firebase console's Web app configuration.

Set-Location ..\flutter
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure --project=field-app-rebeca-sync --platforms=android,web --android-package-name=ro.rau.field_app --yes
```

The project-specific `.env`, `firebase_options.dart`, `google-services.json`,
`.firebaserc` and local test-account credentials are ignored by Git. Examples
are committed; credentials are not. No service-account key is required.

Expo uses Android package `ro.rau.field_app.expo`; Flutter retains
`ro.rau.field_app`. They can be installed together without replacing each other.
Expo uses the Firebase JS Web configuration, so it needs no native Google
services configuration.

## Run

```powershell
# Expo, from expo/
bun run web
# Android: build again after adding AsyncStorage, then start the dev client.
bun x expo run:android --device Pixel_7_API_35

# Flutter, from flutter/
flutter run -d chrome
flutter run -d emulator-5554
```

Android needs the usual JAVA_HOME, ANDROID_HOME and SDK tools on PATH. On this
Windows machine Java is in `C:\src\jbr`. Expo's generated
`android/local.properties` can point CMake to the installed 4.1.2; that local
file is not committed. API 37 and the NDKs must be installed as in Lab 3.

## Optional step 11: road B

```powershell
# Repository root; keep this terminal open.
firebase.cmd emulators:start --project field-app-rebeca-sync
```

For Expo set `EXPO_PUBLIC_USE_EMULATORS=1` and
`EXPO_PUBLIC_UPLOAD_PHOTOS=1` in `.env`, then restart Metro with `--clear`.
For Flutter:

```powershell
flutter run -d chrome --dart-define=USE_EMULATORS=true --dart-define=UPLOAD_PHOTOS=true
flutter run -d emulator-5554 --dart-define=USE_EMULATORS=true --dart-define=UPLOAD_PHOTOS=true
```

Web reaches the services on localhost; the Android emulator uses `10.0.2.2`.
The Emulator UI is at http://127.0.0.1:4000/. Create accounts in the emulator
and seed its pins separately; its database is separate from the live project.
Use `--export-on-exit=emulator-data` and `--import=emulator-data` to preserve
emulator data across runs. The exported directory is Git-ignored.

## Validation

```powershell
# expo/
bun x tsc --noEmit
bun x eslint src --no-cache --quiet
node scripts/sync-smoke.mjs
node scripts/sync-smoke.mjs --emulator

# flutter/
flutter analyze
flutter test test/sync_database_test.dart
flutter build web
```

The smoke check uses two dedicated test accounts. Their generated passwords are
stored only in `.local/test-accounts.json`. It seeds the 20 demonstration pins,
uses the signed-in Firebase CLI account as the office to reassign two pins,
and verifies that the rules reject unauthorized reads, worker reassignment and
a queued survey whose pin has moved. Run it only on a laboratory project.

The database tests cover cloud seeding, reassignment, preservation of pending
and refused surveys, stale acknowledgements and local missed buildings.
Flutter's contract retains its three existing enum naming informational lints.

Detailed results and screenshots are in [docs/week-4](docs/week-4/verification.md).
