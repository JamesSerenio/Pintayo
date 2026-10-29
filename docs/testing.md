# Tests and verification

## Supabase files in VS Code

Open the project root `C:\Projects\pintayo`. The workspace enables the official
`denoland.vscode-deno` extension only for `supabase/functions` and selects the
project-local Deno executable. Other Dart and JavaScript tooling stays scoped to
its own files. Restore the local Deno executable with `npm.cmd ci` in
`tools/database` if dependencies are missing on another checkout.

`supabase/functions/deno.json` defines pinned dependencies for editor checks and
tests. `send-push/deno.json` declares the same dependencies for the deployed
function, including shared modules. Imports use those dependency names rather
than asking the regular TypeScript server to resolve `npm:` URLs. After installing
the extension or changing the workspace setup, run **Developer: Reload Window**
from VS Code's Command Palette if old diagnostics remain.

The functions folder also includes a standard `tsconfig.json`, real npm packages,
and Deno/Node type definitions. This lets VS Code's built-in TypeScript service
resolve the same source correctly when the Deno extension has not taken ownership
of an editor. No synthetic globals or diagnostic suppression are used. Restore
these dependencies with `npm.cmd ci` in `supabase/functions`, then verify with
`npm.cmd run typecheck`. Deno remains the deployment runtime; these npm packages
provide editor resolution and an additional type check.

```powershell
tools/database/node_modules/.bin/deno.cmd check --config supabase/functions/deno.json supabase/functions/send-push/index.ts
tools/database/node_modules/.bin/deno.cmd lint --config supabase/functions/deno.json supabase/functions
tools/database/node_modules/.bin/deno.cmd test --config supabase/functions/deno.json --allow-env supabase/functions/_shared
```

This follows the scoped editor setup in the [Supabase development guide](https://supabase.com/docs/guides/functions/development-environment)
and the per-function dependency setup in [Supabase dependency management](https://supabase.com/docs/guides/functions/dependencies).

## Checks performed in this workspace

- Flutter suite: **30 passed, one live authenticated-backend test explicitly skipped** because test-account credentials were not supplied. Configuration/SDK-header tests also passed separately with `--dart-define-from-file=config/app_config.json` (four tests); those exercise actual config loading and the installed SDK against a local HTTP fixture, not a live user login.
- UI rendering at 320 px and 390 px phone widths and 1024 px tablet width. Real navigation shell, empty friends and tablet map/panel are exercised with clearly isolated test fixtures. Fixtures contain no people or coordinates and use memory-only tiles.
- Embedded PostgreSQL execution of all ordered migrations and assertions for RLS, private profiles/devices, duplicate requests, explicit sharing, expiry, location ordering, circle leave/rejoin, overlapping-grant revocation, blocked sends, durable/idempotent messages and receipt semantics.
- Deno type checking of the trusted Edge Function passed; **six server tests passed**, covering worker authentication, project/registration payloads, failed dispatch with durable message preservation, deduplication, switched/revoked devices and invalid FIDs. All **ten SQL migrations** passed embedded PostgreSQL assertions, including activity, storage, session binding, private device registrations and logout/account transfer.
- Read-only probes of the actual supplied project returned Auth HTTP 200 and rejected anonymous profile/device/search access with HTTP 401. [Evidence and exact limits](integration_status.md). No live accounts were created and no emails sent by these checks.
- Android debug build attempted: **blocked because no Android SDK is installed**. This is not an APK/build success. Windows cannot build/sign an iOS application.

Run normal checks from the root:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze --no-pub
flutter test
flutter test --dart-define=WRITE_PREVIEWS=true
flutter test test/features/backend/backend_security_test.dart
flutter test test/core --dart-define-from-file=config/app_config.json
```

The last command explicitly skips the live test without credentials. It is a backend-only Flutter test and needs no emulator. Screenshot exports load bundled Roboto and Material icons. The tablet screenshot omits network tiles intentionally; it verifies layout, not GPS or tile hosting.

Embedded PostgreSQL and function checks:

```powershell
cd tools/database
npm.cmd ci --no-audit --no-fund
npm.cmd test
cd ../..
tools/database/node_modules/.bin/deno.cmd check --config supabase/functions/deno.json supabase/functions/send-push/index.ts
tools/database/node_modules/.bin/deno.cmd test --config supabase/functions/deno.json --allow-env supabase/functions/_shared
```

The verifier stubs infrastructure tables/functions (`auth.uid`, storage folder paths, realtime topic) but executes PostgreSQL RLS and all handwritten application functions. It omits only `CREATE EXTENSION pgcrypto` because `gen_random_uuid()` is built in. This harness is not a substitute for Supabase Auth/Storage HTTP or websocket delivery tests.

With Supabase CLI and Docker:

```sh
supabase start
supabase db reset
supabase test db supabase/tests/database/authorization_test.sql
```

## Live websocket and storage security test

Provision three **confirmed development-only accounts** on a disposable Supabase project with all migrations applied. Copy the safe example below to ignored `config/backend-tests.json`, fill the public test URL/key and credentials:

```json
{
  "RUN_BACKEND_TESTS": true,
  "TEST_SUPABASE_URL": "https://YOUR-TEST-PROJECT.supabase.co",
  "TEST_SUPABASE_KEY": "YOUR-PUBLIC-KEY",
  "TEST_A_EMAIL": "test-a@example.test",
  "TEST_A_PASSWORD": "replace",
  "TEST_B_EMAIL": "test-b@example.test",
  "TEST_B_PASSWORD": "replace",
  "TEST_C_EMAIL": "test-c@example.test",
  "TEST_C_PASSWORD": "replace"
}
```

```powershell
flutter test test/features/backend/backend_security_test.dart --dart-define-from-file=config/backend-tests.json
```

This mutates the three test accounts: it resets their relationship, creates profiles if absent, creates/stops sharing, creates messages, blocks/unblocks, and leaves durable test messages. Use an isolated database and reset it afterward. It never requires a service-role key. Its open-channel test first proves positive delivery, revokes friendship while keeping the exact same subscription open, publishes another coordinate, then checks both absence of further events and denied reads. It also tests a nonparticipant attachment upload, duplicate message IDs, a fresh client retrieving persisted messages, accurate delivery/read transitions and blocking.

**Not run here:** authenticated hosted RLS/websocket tests, hosted pgTAP, real email, actual storage upload/signed URL behavior, FCM/APNs device delivery, Android native compilation and iOS compilation. No management credentials or native Firebase configuration were available; no hosted migration or function deployment is claimed. The Android build using `config/app_config.json` was attempted and stopped with “No Android SDK found.” Follow [tracking checks](location_tracking.md) for physical-device coverage. Notification tests use explicitly labeled fakes/local transport; their success is not evidence of actual push delivery.
