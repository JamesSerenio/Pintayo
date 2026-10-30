import 'package:pintayo/core/config/app_config.dart';
import 'package:pintayo/core/providers/supabase_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pintayo/app/pintayo_app.dart';

void main() {
  testWidgets('unconfigured app presents private-by-default welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabaseKey: ''),
          ),
        ],
        child: const PinTayoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PinTayo'), findsOneWidget);
    expect(find.text('Magkita sa mapa.'), findsOneWidget);
    expect(find.text('Your location, your choice'), findsOneWidget);
    expect(find.textContaining('Supabase'), findsNothing);
  });
}
