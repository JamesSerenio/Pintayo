# Feature map

Paths below are relative to `lib/features/` unless noted. Features use focused repositories, controllers and presentation components; no combined `screens.dart` or mutable global database client remains.

| Feature | Pages and widgets | Application / data | Migrations and verification |
|---|---|---|---|
| App | `app/shell/adaptive_app_shell.dart`, shared branding/feedback | `bootstrap.dart`, `app/router/`, `core/config/`, `core/providers/` | Auth redirect and adaptive shell widget tests |
| Authentication | `auth/presentation/pages/auth_page.dart` | `auth/application/auth_controller.dart` | Supabase Auth; `test/features/auth/` |
| Onboarding | `onboarding/presentation/pages/permissions_page.dart`, `welcome_page.dart` | Profile and platform public APIs | Responsive widget tests |
| Profile | `profile/presentation/pages/profile_page.dart`, `profile_editor_page.dart` | `profile/data/profile_repository.dart`, `image_upload_service.dart`, `models/profile.dart` | 001, 002, 005, 007; profile RLS assertions |
| Friends | `friends/presentation/pages/friends_page.dart`, `invite_page.dart` | `friends/data/friends_repository.dart` | 001, 005, 006; SQL and live authorization tests |
| Circles | `circles/presentation/pages/circles_page.dart`, `widgets/circle_members_dialog.dart` | `circles/data/circles_repository.dart` | 001, 002, 006, 007; circle lifecycle assertions |
| Location sharing | `location_sharing/presentation/widgets/` | `application/sharing_controller.dart`, `data/location_tracker.dart`, `sharing_repository.dart`, `models/shared_location.dart` | 001, 002, 006; expiry/RLS/order and opt-in open-channel revocation tests |
| Map | `map/presentation/pages/map_page.dart`, `friend_marker.dart`, `selected_profile_sheet.dart` | `map/application/map_controller.dart`, `data/map_tile_provider.dart` | Adaptive shell, empty state and ordering tests |
| Chat | `chat/presentation/pages/`, `widgets/message_bubble.dart`, `message_composer.dart` | `chat/application/chat_controller.dart`, `data/chat_repository.dart`, `models/message.dart` | 001, 002, 005; reconciliation, receipts, persistence/idempotence and live catch-up tests |
| Presence | Conversation header | `presence/application/conversation_presence.dart`, `app_presence_controller.dart` | 001, 003, 008; hidden activity and multi-device server lease assertions |
| Notifications | Permission/settings controls, `notifications/presentation/widgets/notification_banner.dart` | `data/fcm_service.dart`, `device_registration_repository.dart`, `notification_preferences.dart`; `application/notification_controller.dart`, `notification_navigation.dart`; `supabase/functions/send-push/` | 001, 002, 004, 007, 010; controller/account/navigation tests, Deno dispatch/error tests, session-binding SQL assertions; actual device delivery pending |
| Meetups | `meetups/presentation/widgets/meetup_panel.dart` | `meetups/data/meetups_repository.dart` | 001, 007; participant/status authorization |
| Settings | `settings/presentation/widgets/privacy_settings.dart` | Profile/friends/notification APIs | Own-user RLS and lifecycle tests |

The original `202610290001_core.sql` is preserved. Later migrations repair and extend it in order. `tools/database/` provides an embedded PostgreSQL verification harness, `supabase/tests/database/` holds pgTAP tests, and `integration_test/backend_security_test.dart` targets an explicitly configured development project.
