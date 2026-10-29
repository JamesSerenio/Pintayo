# Configure FCM for the existing pintayo project

Firebase is used only for FCM. Keep **Spark**, FCM HTTP v1 enabled and Legacy API disabled. No Firebase Auth, Firestore, Realtime Database, Analytics, Blaze upgrade, VAPID key or legacy server key is needed.

The existing project is **pintayo**, sender/project number **759625922563**. The inspected Android `applicationId` and iOS Runner bundle ID are both **com.example.pintayo**. No Android flavors/suffixes exist. Identifiers have not been changed. CLI access, real native configuration and server credentials were not available here, so **no application registration or live delivery is claimed**.

## Android first, on Windows

Install tools and open a new PowerShell so their executable paths are available:

```powershell
npm.cmd install -g firebase-tools
dart pub global activate flutterfire_cli
firebase.cmd login
firebase.cmd projects:list
firebase.cmd apps:list --project pintayo
```

Inspect the list for an existing Android app matching `com.example.pintayo`. Do not create a second Firebase project or duplicate app. FlutterFire's configuration command matches existing package IDs and reuses them:

```powershell
& "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure --project=pintayo --platforms=android --android-package-name=com.example.pintayo --out=lib/firebase_options.dart
```

The genuine outputs should include `android/app/google-services.json` and `lib/firebase_options.dart`. Check that the Android service file's project ID/number and package match the target; never fill missing fields with invented values. The app's Gradle configuration applies Google Services only when the real JSON exists. No missing generated Dart file is imported: mobile initialization uses the genuine native files, then checks project/sender metadata. Generated options may remain available for tooling without adding a broken import while setup is pending.

Alternatively, in Firebase Console → **pintayo** → Project settings → Your apps, reuse/add an Android app with package **com.example.pintayo** and download its genuine JSON. Do not register a web app for this mobile-only flow. The native Kotlin code creates channel **pintayo_messages**, and the manifest sets it as FCM's default channel and opts into FID registration.

After genuine Android configuration is present, set `ENABLE_PUSH` to `true` in `config/app_config.json`, then:

```powershell
flutter run --dart-define-from-file=config/app_config.json
flutter build apk --dart-define-from-file=config/app_config.json
```

An Android SDK and a real device/emulator with compatible Google Play services are required. None was available in this workspace. Android 13+ notification permission is requested only from the explicit enable-notifications control. The release build still needs your production signing configuration before store publication.

## iPhone/iPad and APNs

On a Mac with the matching source tree and authenticated CLIs:

```sh
flutterfire configure --project=pintayo --platforms=android,ios --android-package-name=com.example.pintayo --ios-bundle-id=com.example.pintayo --out=lib/firebase_options.dart
```

Reuse the iOS app matching **com.example.pintayo**. Add the genuine `ios/Runner/GoogleService-Info.plist` to Runner's target/resources. Check its project number, project ID and bundle ID. In Xcode choose your real signing team/profile and enable Push Notifications and Background Modes (remote notifications, plus location updates for the existing sharing feature). Supply an APNs authentication key to Firebase, with the correct team/key IDs. Let signing provision the real `aps-environment`; do not fabricate an entitlement or APNs key.

Use Swift Package Manager for the installed Firebase packages (Firebase Core 5.1.0 / Messaging 17.0.1, native Firebase SDK 13). Runner already targets iOS 15. If disabled locally, enable Flutter SPM with `flutter config --enable-swift-package-manager`, then let Flutter regenerate ephemeral packages. Firebase 13 requires a supported modern Xcode; old CocoaPods-only Firebase distributions do not provide the current FID APIs. Test development and distribution APNs signing on actual devices. No iOS compilation/device testing was possible on Windows.

## Client behavior and lifecycle

`fcm_service.dart` handles genuine initialization, the separate permission request, `onRegistered`/`register()`/`onUnregistered`/`unregister()` and the VM-safe background entry point. FIDs are stored privately in the existing `devices.token` column and dispatched through `message.fid`, consistently with Messaging 17. No deprecated token API is mixed into registration management.

Background OS notification payloads are displayed by FCM. The background handler does not display a second alert, navigate, or acknowledge chat receipts. Foreground OS presentation is disabled on Apple; the app shows one deduplicated in-app banner. Taps and terminated launches route to a conversation or the friend-request tab, retaining the destination through login and checking the recipient account.

`notification_controller.dart` retains opt-in per account, serializes registration writes, rejects stale callbacks during account switches and cleans up on explicit logout. Migration **010** links registrations to real Supabase Auth sessions. The worker excludes removed/expired sessions and stale installation generations. Other devices remain registered under their own sessions. Already displayed/in-flight OS notifications cannot be recalled; future server dispatch uses current authorization.

Missing Firebase configuration is contained and reported as notifications unavailable in settings; Supabase sign-in, chat, friends and maps remain usable. Metadata alone never produces a fake successful registration.

## Trusted Supabase dispatch and secrets

Apply pending migrations before enabling registration and deploy the worker to **djqnavpwrkgcylwvdoxa**. Its fixed destination is:

```text
https://fcm.googleapis.com/v1/projects/pintayo/messages:send
```

Create/download the genuine server service-account JSON for **pintayo**, with FCM send permission, to a private directory **outside this repository**. Do not paste it into chat or put it in Flutter configuration. Authenticate Supabase CLI, review the helper, and run it from PowerShell. The command below uses a process-scoped policy for local scripts; it does not change the machine policy:

```powershell
npx.cmd supabase login
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tool\set_push_secrets.ps1 -ServiceAccountPath 'C:\Private\pintayo-service-account.json'
npx.cmd supabase functions deploy send-push --project-ref djqnavpwrkgcylwvdoxa
```

The helper validates the project, uploads `FCM_SERVICE_ACCOUNT` and `PUSH_WORKER_SECRET` via a temporary private dotenv file, removes that temporary file, and never prints secret values. It saves/reuses a random worker secret beside your private service-account file for the matching Vault setup. Keep that private folder restricted to your Windows account. The worker uses Supabase's automatic **server-only** service-role environment; the app's publishable key and Firebase sender ID are never used as server OAuth credentials.

In the Supabase project's Vault UI create:

- `pintayo_project_url` = `https://djqnavpwrkgcylwvdoxa.supabase.co`.
- `pintayo_push_worker_secret` = the exact secret from the helper's private `pintayo-push-worker-secret.txt` file.

Run `supabase/ops/schedule.sql` once in that project's SQL Editor. It schedules expiration cleanup and the authenticated push worker. The minute schedule trades latency for small-pilot simplicity; it does not send a push for each location update. Review existing named cron jobs before adding duplicates.

The endpoint deliberately uses `verify_jwt=false` with its own mandatory `x-worker-secret` check. No anonymous/client request can select arbitrary recipients or notification contents. Dispatch validates each queued event and current block/friend/session/device state. Messages are saved before enqueue/dispatch. Failures leave the event retryable and the message intact. Delivery records and collapse IDs reduce duplicates, with bounded retries; an interrupted external send cannot promise exactly-once delivery. FCM acceptance never sets delivered/seen chat receipts.

## Evidence and device checks

Controller/adapter/navigation tests and server transport-failure simulations run without a Firebase account. Deno type checks and embedded SQL validate the implementation, not real device delivery. After setup, use two confirmed Supabase test users on two configured devices to check foreground banner, background OS alert, terminated tap, wrong-account tap, logout, account switch, FID invalidation, permission denial and message catch-up. Verify that transport acceptance alone leaves receipts at Sent, then Delivered/Seen only after recipient-app acknowledgement.

Sources: [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup), [FlutterFire CLI](https://github.com/invertase/flutterfire_cli), [FCM registration](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [foreground/background handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [FCM HTTP v1](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages).
