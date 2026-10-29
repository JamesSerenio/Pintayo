# PinTayo

**Magkita sa mapa.** Private location sharing, circles, and conversations for Android phones/tablets and iPhone/iPad.

The existing Flutter project has been continued in place. Firebase is used only for FCM. Maps use `flutter_map` and configurable OpenStreetMap tiles. Supabase owns authentication, Postgres, private images, realtime, and trusted notification dispatch. No sample people or coordinates populate production screens.

## Run locally

Developed with Flutter **3.44.8 / Dart 3.12.2**. Use a compatible stable Flutter SDK, Android SDK (Android 7/API 24 minimum), or macOS/Xcode for iOS 15+. Commit `pubspec.lock` for reproducible dependency resolution.

```powershell
flutter pub get
# config/app_config.json already contains the supplied public project config.
# On another checkout, copy config/app_config.example.json and fill its values.
```

The supplied Supabase URL and publishable key are in ignored `config/app_config.json`, alongside Firebase project metadata. Do not put service-role or service-account credentials there. Firebase metadata is insufficient to initialize FCM: push remains disabled until genuine native files are installed. See [actual integration status](docs/integration_status.md) for connectivity evidence and remaining access/setup.

```powershell
flutter run --dart-define-from-file=config/app_config.json
flutter build apk --dart-define-from-file=config/app_config.json
```

Without configuration, `flutter run` shows the branded availability screen. It does not pretend to connect. Follow [Supabase setup](docs/supabase_setup.md) before testing sign-in. Push is optional and disabled by default; see [FCM setup](docs/fcm_setup.md). Android debug HTTP is allowed only for local development by the debug manifest.

On macOS, configure the real bundle ID and signing team, then:

```sh
flutter pub get
flutter build ios --no-codesign --dart-define-from-file=config/app_config.json
```

Use Swift Package Manager with the installed Firebase SDK; see the platform notes in FCM setup. An archive for distribution requires actual signing credentials. The inspected Android and iOS Runner IDs are both `com.example.pintayo` and are preserved. Use those exact IDs when registering matching Firebase apps for this project. Android release signing is still the starter debug signing configuration and must be replaced before publishing.

## Implemented flows

- Registration, sign-in, email password recovery, profile completion and editing, compressed private profile photos.
- Friend search, requests, accept/decline/cancel, removal, blocks, QR and link invites; private circles with invitations and owner member removal.
- Explicit sharing audience, duration, pause/resume/stop, server expiration and revocation, native location streams, map following, animated friend markers, freshness/accuracy and straight-line distance.
- Durable one-to-one text/photo chat, previews/unread counts, pagination, reconnect catch-up, manual idempotent retry, recipient-acknowledged receipts, presence and typing.
- Private device registration and an authenticated, leased FCM worker for messages/requests, with notification navigation.
- Map long-press meet-up pins, selected guests/circles, participant statuses, and no invented ETA.
- Emerald/navy design, four phone tabs, and map-plus-panel tablet layouts.

## Verification

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze --no-pub
flutter test
flutter test --dart-define=WRITE_PREVIEWS=true
cd tools/database
npm.cmd ci --no-audit --no-fund
npm.cmd test
```

The embedded PostgreSQL verifier executes all migrations with Supabase infrastructure schemas stubbed, then exercises real PostgreSQL functions and RLS. It is independent of a Supabase account; it cannot test websocket delivery. [Testing details](docs/testing.md) include the opt-in live open-channel revocation test and pgTAP commands.

Screenshots of implemented widgets: [sign-in](docs/previews/sign-in-390.png), [phone friends](docs/previews/friends-320.png), [tablet shell](docs/previews/friends-1024.png). The shell previews intentionally use an empty development fixture and transparent map tiles; they are not evidence of backend/GPS connectivity.

## Project guides

- [Architecture and lifecycle](docs/architecture.md)
- [Actual Supabase/Firebase integration and evidence](docs/integration_status.md)
- [Feature-to-file map](docs/feature_map.md)
- [Supabase and email setup](docs/supabase_setup.md)
- [FCM and APNs](docs/fcm_setup.md)
- [Location permissions and physical-device checks](docs/location_tracking.md)
- [Tests and verification results](docs/testing.md)
- [Pilot usage and costs](docs/free_tier_usage.md)

Live backend, email delivery, websocket revocation, FCM delivery, and background GPS still require your external configuration and device verification. No credentials or Firebase configuration have been fabricated.
# Pintayo
