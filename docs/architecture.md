# Architecture

`main.dart` calls `bootstrap.dart`. Startup validates environment configuration and initializes Supabase when both public values exist. `app/` owns the theme, GoRouter redirects and adaptive shell. Features never import the entry point. `core/` supplies configuration, network signals, errors and the injected Supabase client. `shared/widgets/` contains reusable feedback, branding and private image widgets.

Repositories implement database and storage access. Riverpod providers construct repositories and own controller lifetimes. Feature controllers hold application state; `ListenableBuilder` renders their notifications. Device integrations live under location sharing and notifications. Models decode data at boundaries, including message receipt semantics and ordered location fixes.

`SessionServices` holds sharing and app presence across authenticated navigation. The application-scoped notification controller independently observes Auth, including signed-out startup, so notification taps can survive login and stale registrations can be invalidated on account changes. SessionServices receives durable message events and acknowledges only message IDs actually received or queried. It does not mark them seen. The open conversation acknowledges its loaded messages as seen only while foregrounded. Account changes clear cached user state, terminate scoped channels and stop the native tracker. Explicit logout stops sharing, removes the device registration, then signs out the local Auth session; other devices retain their own sessions.

## Authorization boundaries

All exposed application tables enable RLS in their introducing migration. Direct mutations are revoked except own profile fields and own device deletion. Trusted RPCs derive their actor from `auth.uid()`. Search returns ID, username, display name and avatar path, never email, coordinates or device registrations. Avatar objects are private; attachment paths include conversation and sender IDs and are participant-authorized.

Location fixes live in one owner row and recipient-specific current inbox rows. `publish_location` validates the active session, ordering, fix time, coordinates and accuracy; it writes only currently authorized recipients. The inbox RLS policy rechecks the current authorization graph for ordinary reads and each Postgres Changes event. No broadcast/presence payload carries a coordinate. Realtime channel admission is never the source of location authorization.

Circle audiences snapshot accepted members when sharing starts. Both current membership and the snapshot are required. Leaving/removal invalidates snapshots. Friend removal/blocking excludes that pair from existing sessions, including overlapping circle grants. Rejoining/re-friending does not restore the old grant. A new explicit sharing start is required. Expiration is enforced against database time, independently of UI timers and cron maintenance.

## Reconnection and activity

Messages are durable rows with client-generated UUIDs. A retry reuses the UUID and returns the original saved row. History uses `(created_at,id)` cursors. On reconnect, the controller retrieves every page after its cursor, merges by ID, refreshes receipts for loaded rows, and reconciles the newest page. Connectivity signals disable sending when no interface exists; server failures still produce a visible failure/manual retry because an interface does not prove internet access. There is no automatic offline outbox.

Supabase Presence channels are private to a user's own devices, with independent connection keys. A server-timed foreground activity lease and typing deadline provide cross-user status through `chat_activity` and per-event RLS. This prevents another device with a cached visibility preference from leaking new activity after hiding status. Background GPS never refreshes a foreground lease. `chat_activity`/`person` enforce visibility and blocking, including direct reads of activity rows. Presence is approximate and crashes can remain visible for up to 75 seconds. Already-disclosed timestamps cannot be recalled.

The leased notification queue contains references to durable events. A worker validates each event against current access, binds recipients to active Auth sessions and rechecks installation generations before sending generic notifications to Firebase project pintayo through HTTP v1. It records per-installation acceptance separately from chat receipts. The injectable dispatcher has no message-update API. Provider acceptance is not proof of device delivery. Transport retries are at-least-once around an interrupted external HTTP call; stable event IDs, delivery records and collapse IDs reduce duplicates rather than promising end-to-end exactly-once delivery.

## Scope and future extension

This pilot uses bounded lists (100 friends/circles/conversations and 50 meetups), 40-message history pages and 200-message catch-up pages. Expand list pagination before increasing those caps. No permanent movement history or road-routing service exists. Straight-line distance is computed on device, so PostGIS is unnecessary for current queries; introduce it when implementing server-side geographic filtering.
