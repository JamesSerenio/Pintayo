# Supabase setup

## Message reactions

The next additive migration, `202610300002_chat_message_actions.sql`, adds forwarding, replies and deletion state. Deploy the `message-actions` Edge Function as well; see [chat message actions](chat_message_actions.md) for the complete setup and cleanup schedule.

Apply pending migration [202610300001_message_reactions.sql](../supabase/migrations/202610300001_message_reactions.sql) before using emoji reactions. With an authenticated, linked CLI, inspect `npx.cmd supabase migration list --linked`, then `npx.cmd supabase db push --dry-run` and `npx.cmd supabase db push`. Do not rerun older migrations manually. This workspace has validated the migration locally; it has not applied it to the hosted project.

Long-press a message to choose a reaction. Choosing your existing emoji removes it; choosing another replaces it. Each participant has one reaction per message. Reactions persist in Postgres and refresh through Realtime with reconnect recovery. Only chat participants can read them; writes require accepted, unblocked friends. Reactions never acknowledge delivery or reading. The migration adds the table to the Realtime publication.

Tap a message to toggle its time and outgoing receipt. Tap an attached photo to open the full-screen viewer and pinch to zoom. Photos continue to use authorized, temporary URLs from the private attachment bucket.

## Local stack or hosted development project

Install Docker and the Supabase CLI for the local stack. From the repository root:

```sh
supabase start
supabase db reset
supabase status
```

`db reset` resets the **local development database** and applies the ordered migrations. Do not use reset against production. Local email confirmations can be opened in the mail viewer URL printed by `supabase status`.

For the supplied hosted project, authenticate the management CLI (the publishable app key cannot manage migrations):

```sh
npx.cmd supabase login
npx.cmd supabase link --project-ref djqnavpwrkgcylwvdoxa
npx.cmd supabase migration list --linked
npx.cmd supabase db push --dry-run
npx.cmd supabase db push
```

Inspect migration status before pushing to an existing project. Do not edit or delete previously applied migration files. The original core migration is retained; corrections are subsequent migrations. Enable Realtime in the project; migrations add the location inbox, messages, friendships, notifications and activity sessions to the `supabase_realtime` publication. Presence channels are private to a user's own devices. Cross-user activity and typing use per-event RLS and the visibility-filtered status RPC.

The supplied public URL and **SUPABASE_PUBLISHABLE_KEY** are defaults in `AppConfig.environment`, so `flutter run -d chrome` opens sign-in when signed out. The ignored `config/app_config.json` can still override defaults with `--dart-define-from-file=config/app_config.json`. No secret/service-role key belongs in Flutter assets, Dart defines, Android resources or iOS resources. Explicitly empty URL and key show the availability screen. The live public probes accepted the key and rejected anonymous profile/device/search access; authenticated access and hosted migration versions still need accounts/management access. No hosted schema or function was changed from this workspace.

Migrations 001–009 are preserved. New migration **010_push_session_binding** must be applied before the revised notification client/worker is enabled. It uses `auth.sessions` and the SDK user's `session_id` JWT claim, so revoked sessions cannot create usable registrations or receive future dispatch. Existing unbound registrations are excluded until re-registered. If prior SQL was applied manually without migration tracking, reconcile the actual schema and migration history before pushing; do not rerun the core migration or use `--include-all` blindly.

## Auth and email

Allow `pintayo://app/auth` and `pintayo://app/recovery` in Auth redirect URLs. Email confirmation is enabled in the local example. Configure a production HTTPS landing/redirect domain before publishing invite links; register Android App Links and Apple Universal Links if replacing the development custom scheme. Configure your chosen `INVITE_BASE` consistently with the domain association files and application routes. Native camera applications can scan the invite QR; there is no in-app camera scanner.

For launch, configure custom SMTP, verify the sender domain, configure SPF/DKIM/DMARC, inspect email templates and confirmation/reset links, and review rate limits, abuse prevention and password policy. The development mail service and default hosted email limits are not a public delivery solution. Email/password is implemented; OAuth is optional and not configured.

## Storage and privacy

Migrations create private `avatars` (JPEG, 2 MB) and `attachments` (JPEG, 5 MB) buckets. The app validates input size, converts/compresses to JPEG and strips EXIF. Object names contain the owner, and attachment names also contain the conversation. Replacing a saved avatar attempts to delete the old object; canceled uploads may leave unreferenced objects, so add an administrator cleanup job before expanding the pilot.

Signed image URLs are short-lived bearer URLs (15 minutes). Access is checked when the URL is issued. A previously issued URL can remain usable until expiry; revoking a friendship cannot recall downloaded images. Coordinates never use signed URLs or storage objects. Device registrations and notification dispatch bookkeeping are private. Search only exposes minimal identity fields.

## Scheduled maintenance and notification dispatch

`expire_sharing()` is service-only. Its cleanup is separate from RLS, which denies expired reads immediately. Enable `pg_cron` and `pg_net` in the hosted project. Run the expiration schedule from `supabase/ops/schedule.sql` even when push is disabled. It removes expired inbox/current fixes without storing movement history. For push, follow FCM setup, create Vault secrets `pintayo_project_url` and `pintayo_push_worker_secret`, then run the push schedule from the same file once. Reapplying a named schedule should be reviewed in the Cron dashboard to avoid duplicate jobs.

Keep the worker secret identical in Vault and the Edge Function secrets. The worker uses `x-worker-secret`, validates durable events, leases queue rows, and never accepts caller-selected recipients. Its endpoint JWT gateway is disabled deliberately because the worker uses a dedicated secret; never deploy a version that omits that header check.

## Verify access

```sh
supabase test db supabase/tests/database/authorization_test.sql
```

Run the live websocket test described in [testing](testing.md). Embedded PostgreSQL assertions are useful before deployment but do not replace actual Supabase Realtime or Storage HTTP verification. Check the Supabase security advisor after deployment and review any intentionally exposed public schema objects.
