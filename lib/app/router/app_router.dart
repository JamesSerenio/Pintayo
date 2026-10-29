import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/feedback_views.dart';
import '../../core/providers/supabase_provider.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/onboarding/presentation/pages/welcome_page.dart';
import '../../features/onboarding/presentation/pages/permissions_page.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/pages/profile_editor_page.dart';
import '../../features/chat/presentation/pages/conversation_page.dart';
import '../../features/friends/presentation/pages/invite_page.dart';
import '../shell/adaptive_app_shell.dart';
import 'auth_redirect.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(configProvider);
  final auth = config.isConfigured ? ref.watch(authControllerProvider) : null;
  final router = GoRouter(
    errorBuilder: (context, state) =>
        Scaffold(body: ErrorView(onRetry: () => context.go('/map'))),
    initialLocation: '/map',
    refreshListenable: auth,
    redirect: (context, state) async {
      final signedIn = auth?.userId != null;
      final profile = signedIn
          ? await ref.read(profileRepositoryProvider).current()
          : null;
      final destination = authDestination(
        configured: config.isConfigured,
        signedIn: signedIn,
        recovering: auth?.recovering ?? false,
        onboarded: profile?.onboarded ?? false,
        location: state.uri.path,
      );
      if (destination == '/map' && state.uri.queryParameters['next'] != null) {
        final recipient = state.uri.queryParameters['notificationRecipient'];
        if (recipient != null && recipient != auth?.userId) return '/map';
        return returnLocation(state.uri.queryParameters['next']);
      }
      if (destination == '/onboarding') {
        return '/onboarding?next=${Uri.encodeComponent(returnLocation(state.uri.toString()))}';
      }
      if (destination?.startsWith('/auth') == true) {
        return '/auth?next=${Uri.encodeComponent(state.uri.toString())}';
      }
      return destination;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthPage()),
      GoRoute(
        path: '/recovery',
        builder: (_, _) => const AuthPage(recovery: true),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const ProfileEditorPage(onboarding: true),
      ),
      GoRoute(path: '/permissions', builder: (_, _) => const PermissionsPage()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileEditorPage(),
      ),
      GoRoute(
        path: '/invite/:id',
        builder: (_, s) => InvitePage(userId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) =>
            ConversationPage(conversationId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/:tab',
        builder: (_, s) => AdaptiveAppShell(
          tab: s.pathParameters['tab']!,
          showRequests: s.uri.queryParameters['requests'] == 'true',
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
