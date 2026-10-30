import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pintayo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:pintayo/features/chat/data/models/message.dart';
import 'package:pintayo/shared/widgets/private_image.dart';

void main() {
  Message fixture({String? photo}) => Message(
    id: 'message',
    conversationId: 'conversation',
    sender: 'self',
    body: photo == null ? 'Hello there' : null,
    attachment: photo,
    createdAt: DateTime(2026, 10, 30, 8, 5),
    seenAt: DateTime(2026, 10, 30, 8, 6),
  );

  testWidgets('time and receipt are hidden until the message is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessageBubble(message: fixture(), mine: true)),
      ),
    );
    expect(find.textContaining('Seen'), findsNothing);
    await tester.tap(find.text('Hello there'));
    await tester.pump();
    expect(find.textContaining('Seen'), findsOneWidget);
    await tester.tap(find.text('Hello there'));
    await tester.pump();
    expect(find.textContaining('Seen'), findsNothing);
  });

  testWidgets('long press offers reactions and sends the chosen emoji', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: fixture(),
            mine: true,
            reactions: const {'friend': '❤️'},
            onReact: (emoji) async {
              chosen = emoji;
            },
          ),
        ),
      ),
    );
    expect(find.text('❤️'), findsOneWidget);
    await tester.longPress(find.text('Hello there'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect(chosen, '👍');
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('photo opens a full screen viewer with zoom and close', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedImageProvider((
            'attachments',
            'test-photo',
          )).overrideWith((ref) async => 'https://test.invalid/photo.png'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: fixture(photo: 'test-photo'),
              mine: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Open photo'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close photo'), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
