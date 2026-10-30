import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/app/shell/adaptive_app_shell.dart';
import 'package:pintayo/features/map/presentation/pages/map_page.dart';
import '../../support/empty_app_fixture.dart';
import '../../support/preview_capture.dart';

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 1024.0]) {
    testWidgets(
      'real empty shell renders at $width without location permission',
      (tester) async {
        tester.view.physicalSize = Size(width, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          emptyAppFixture(
            RepaintBoundary(
              key: boundary,
              child: const AdaptiveAppShell(tab: 'friends'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Your people'), findsOneWidget);
        expect(find.text('Good things start with hello'), findsOneWidget);
        expect(
          find.byType(NavigationBar),
          width < 840 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(NavigationRail),
          width >= 840 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(MapPage),
          width >= 840 ? findsOneWidget : findsNothing,
        );
        await capturePreview(tester, boundary, 'friends-${width.toInt()}');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Logout/unmount disposes subscriptions and notifiers',
        );
      },
    );
  }
}
