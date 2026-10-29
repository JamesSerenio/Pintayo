import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/app/theme/app_theme.dart';
import 'package:pintayo/features/auth/presentation/pages/auth_page.dart';
import 'package:pintayo/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:pintayo/features/chat/presentation/widgets/message_composer.dart';
import '../../support/preview_capture.dart';

void main() {
  setUpAll(loadPreviewFonts);
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('welcome and sign in fit ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final entry in [
        ('welcome', const WelcomePage()),
        ('sign-in', const AuthPage()),
      ]) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: RepaintBoundary(key: boundary, child: entry.$2),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capturePreview(
          tester,
          boundary,
          '${entry.$1}-${size.width.toInt()}',
        );
      }
    });
  }
  testWidgets('offline composer disables sends without silently queueing', (
    tester,
  ) async {
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            enabled: false,
            sending: false,
            onSend: (_) async {
              sends++;
            },
            onPhoto: () {
              sends++;
            },
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Papunta na'));
    expect(sends, 0);
    expect(find.textContaining('Nothing is queued'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
