import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'shell/session_services.dart';
import '../features/notifications/presentation/widgets/notification_banner.dart';

class PinTayoApp extends ConsumerWidget {
  const PinTayoApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'PinTayo',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    routerConfig: ref.watch(appRouterProvider),
    builder: (context, child) =>
        SessionServices(child: NotificationBanner(child: child!)),
  );
}
