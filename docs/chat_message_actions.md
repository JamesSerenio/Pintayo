# Chat message actions

The photo renderer fits decoded portrait/landscape images inside 300 × 360 logical pixels without a colored background or cover-cropping. Captions use a separate text bubble. Tap photos for the existing full-screen zoom viewer; long-press or right-click text/photos for the same action sheet.

The reaction row is exactly ❤️ 😆 😮 😢 😠 👍. Received messages offer Copy, Forward, Reply and Delete for me. Own messages offer Copy, Forward, Reply and Delete; Delete opens a separate scope sheet before a No/Yes confirmation. The menu guard prevents opening several action flows together. Sheets dismiss before the next stage opens.

## Files

- `lib/features/chat/data/models/message.dart`: reply identity, forwarded marker, tombstones and monotonic revision reconciliation.
- `data/message_actions_repository.dart`, `data/message_copy_service.dart`, `data/image_clipboard*.dart`: authenticated operations, actual text clipboard, browser image clipboard and honest unsupported-device fallback.
- `application/message_actions_controller.dart`, `application/chat_controller.dart`, `application/message_reactions.dart`: action flow, replies, visibility reconciliation, cache invalidation and reactions.
- `presentation/widgets/image_message.dart`, `message_action_sheet.dart`, `message_reaction_bar.dart`, `delete_message_sheet.dart`, `delete_message_dialog.dart`, `forward_message_sheet.dart`, `reply_composer_preview.dart`, `quoted_message_preview.dart`, and the updated `message_bubble.dart`: focused UI components.
- Updated `presentation/pages/conversation_page.dart` and `lib/app/shell/session_services.dart`: integration and cross-session refresh.
- `supabase/migrations/202610300002_chat_message_actions.sql`: additive schema/RLS/RPC changes; existing migrations remain unchanged.
- `supabase/functions/message-actions/`: validated user JWT entry point for trusted forwarding and photo removal. `_shared/message_attachment_copy.ts` and `_shared/attachment_cleanup.ts` use supported Storage operations.

## Server behavior

`hidden_messages` stores one message/account pair. RLS, pages, receipt/context lookups, summaries and search consistently exclude that viewer's hidden messages. Other participants retain their messages, attachments and reply access. Hidden-row Realtime events update the same account's other sessions.

Global deletion checks the original sender, retains the message ID/reply relationship, nulls the actual body/attachment, increments a revision and removes reactions. The renderer shows a neutral placeholder; quoted context is resolved from current authorized rows rather than a stored content snapshot. Late snapshots cannot overwrite a tombstone. Reconnect refresh removes hidden rows and refreshes all loaded message IDs and reply targets, including older pages.

The forward worker verifies the JWT with Auth and asks a caller-scoped RPC to validate source and destination access. Source/destination must be participant conversations with accepted, unblocked friends. A stable request UUID reserves an independent message/attachment path. Storage.copy creates a separate object; retries encountering an existing object verify matching SHA-256 bytes. The service-only finalizer rechecks source deletion/visibility and destination access before inserting the new message. No original history or source signed URL is sent to the destination. Independently forwarded messages survive original deletion.

Global photo deletion queues the original object for removal and revokes new signing access. The Edge Function removes it through the Storage API, then acknowledges the queue. Failed removals remain queued. Unfinished forward copies become eligible for cleanup after one hour. Cleanup never selects objects referenced by a live message. Existing signed URLs or independently downloaded content cannot be retroactively erased by a UI action; URL expiry, cache lifetime and successful object removal determine remaining access to previously issued URLs.

Copy writes complete text/captions without UI metadata. Supported secure web browsers use ClipboardItem with a PNG Blob (and caption text when supplied). Clipboard permissions can deny the operation. Native/text-only clipboard builds clearly explain the photo-copy limitation and never substitute a private storage URL.

## Hosted setup still required

No hosted migrations/functions were applied by this workspace. No management token or linked project is available here.

1. With the authenticated Supabase CLI, inspect migration history before applying pending migrations:

   ```powershell
   npx.cmd supabase link --project-ref djqnavpwrkgcylwvdoxa
   npx.cmd supabase migration list --linked
   npx.cmd supabase db push --dry-run
   npx.cmd supabase db push
   npx.cmd supabase functions deploy message-actions --project-ref djqnavpwrkgcylwvdoxa
   ```

   Apply both pending reaction and message-action migrations in order. Do not rerun existing core SQL. Supabase supplies the function's server URL, anon key and service-role key; private credentials stay on the server. `verify_jwt=false` is intentional because the handler explicitly validates the caller with `auth.getUser(token)` before any user action. The scheduled cleanup path instead requires the existing dedicated `PUSH_WORKER_SECRET`.

2. For automatic cleanup retries, ensure pg_cron/pg_net and the existing project URL/worker secret Vault entries are configured as described in Supabase setup. Apply `supabase/ops/schedule_message_cleanup.sql` once after deployment. Cleanup also runs after authenticated delete/forward actions.
3. Redeploy the generated `build/web` to Vercel. A Vercel-only redeploy cannot install the backend migration or Edge Function.

## Verification

Flutter tests cover exact menus/reactions, delete cancellation, tombstones, stale snapshots, clipboard text/caption behavior, photo viewer, and actual decoded portrait/landscape rendering for incoming/outgoing photos. PostgreSQL tests run all migrations and verify per-account visibility, raw RLS/RPC authorization, replies, global redaction, forwarded copies and cleanup selection with disposable fixtures. The embedded database simulates Storage object metadata only; it does not perform live Storage HTTP copies. Deno tests check copy retry conflicts and durable removal retries using injected clients.

Live two-account browser/device testing and hosted Storage/Realtime operations require deployment and test accounts. Existing user history has not been deleted to test these changes.
