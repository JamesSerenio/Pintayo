# Actual project integration

The application now loads the supplied Supabase project and Firebase metadata from ignored `config/app_config.json`. `config/app_config.example.json` is the safe distributable template. The URL/key are centralized; repositories continue to consume the injected Supabase client. Installed `supabase_flutter` **2.18.3** is initialized with `publishableKey`, not a custom Authorization header or a fabricated user JWT. A legacy `SUPABASE_ANON_KEY` fallback remains for older developer configs; all new commands use `SUPABASE_PUBLISHABLE_KEY`.

## Evidence from 29 October 2026

Read-only public requests reached **djqnavpwrkgcylwvdoxa.supabase.co** using the supplied key in `apikey`:

| Probe | Result |
|---|---|
| Auth settings | HTTP 200; email sign-in enabled, sign-up enabled |
| Anonymous profile access | HTTP 401, `42501` |
| Anonymous device-registration access | HTTP 401, `42501` |
| Anonymous scoped user search | HTTP 401, `42501` |

Machine-readable evidence: [public probes](verification/supabase-public-probes.json). No profile rows, device values or session tokens are logged. These results prove public connectivity and anonymous privilege rejection; they do **not** prove authenticated login, complete hosted migration history, authenticated cross-account RLS, Storage uploads or realtime delivery. Those need test-account credentials or management access.

The build-time configuration tests were run with `--dart-define-from-file=config/app_config.json`. A local HTTP fixture also exercised the actual installed Supabase SDK: requests used the public API key, and authenticated REST requests used the test user's session JWT. It did not create an account on the real project or send email.

## Firebase state

The supplied target is **pintayo**, sender/project number **759625922563**, Spark plan. No plan or billing changes were made. No Firebase apps were registered by this task: no Firebase/FlutterFire CLI, account session, default Google credentials or genuine native files were available. Existing IDs were inspected and preserved:

| Platform | ID | Variants |
|---|---|---|
| Android | `com.example.pintayo` | No flavors or application-ID suffixes found |
| iOS Runner | `com.example.pintayo` | Same bundle ID in Debug/Profile/Release |

`ENABLE_PUSH` remains **false** until genuine native configuration is installed. Project number/sender ID are never used to construct fake API keys or application IDs. The code initializes from native Firebase files and verifies their project/sender against configured metadata. It does not import a missing `firebase_options.dart`.

## Implementation and checks

- Focused FCM adapter, private registration repository, account-scoped preferences, application controller, account-aware navigation and one foreground banner.
- Native Android channel `pintayo_messages`; background entry point; permission opt-in; current FID registration/refresh/invalidation APIs; cold-start taps and matching-account login.
- New **010** migration binds each registration to its authenticated session and generation. The service-only dispatch query excludes revoked/expired sessions. Account switching transfers an installation; explicit logout deletes its registration before ending that device's Auth session. Other devices retain their own sessions.
- The trusted worker targets `https://fcm.googleapis.com/v1/projects/pintayo/messages:send`, checks the dedicated secret, validates durable events/blocks and rechecks each device before dispatch. Invalid FIDs are removed; retry/dedup bookkeeping remains independent of saved messages and delivery/read receipts.
- Unit tests cover logout, account-switch races, refresh/invalidation, missing native configuration, foreground duplicate suppression and navigation through login. Server tests simulate FCM errors, invalid registrations and access revocation without contacting FCM. Embedded PostgreSQL checks cover session binding, private registrations, account transfer and persistence across dispatch failure.

No actual push was sent or received on a device. A simulated successful transport is a unit-test result, not proof of real delivery.

## Remaining external actions

The full Flutter suite passed **30 tests**, with one credential-dependent live test skipped. Four config/SDK tests passed with the real build-time config. Deno type checking and six server tests passed. All ten migrations executed successfully in embedded PostgreSQL. The PowerShell secret helper parsed successfully but was not executed. Android build with the actual config stopped because the Android SDK is absent; native notification-channel/device behavior remains unverified.

1. Authenticate Supabase CLI and inspect/apply pending migrations to project `djqnavpwrkgcylwvdoxa`. No hosted migration, bucket, function or secret was changed by this task. Existing migrations **001–009 are preserved**, with **010** added. Follow [Supabase setup](supabase_setup.md); do not re-run already-applied SQL blindly.
2. Authenticate Firebase CLI, list existing applications, then configure Android in **pintayo** with package `com.example.pintayo`. Reuse a matching app. Generate genuine native configuration before enabling push. [Exact Windows commands](fcm_setup.md).
3. Configure the corresponding iOS app on Mac, add its genuine plist, signing capabilities and APNs authentication key. No VAPID or legacy server key is needed.
4. Upload the real service account through the private-file helper, deploy `send-push`, set Vault secrets and enable the cron jobs. Never paste the private key into chat or application configuration.
5. Install the Android SDK/device tooling, run the app/build commands in README and exercise real test accounts and configured devices. Test real FCM delivery separately from transport acceptance.
