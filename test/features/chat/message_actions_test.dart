import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/features/chat/presentation/widgets/message_action_sheet.dart';
import 'package:pintayo/features/chat/presentation/widgets/message_reaction_bar.dart';
import 'package:pintayo/features/chat/presentation/widgets/delete_message_sheet.dart';
import 'package:pintayo/features/chat/presentation/widgets/delete_message_dialog.dart';
import 'package:pintayo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:pintayo/features/chat/presentation/widgets/quoted_message_preview.dart';
import 'package:pintayo/features/chat/data/models/message.dart';

void main() {
  for (final mine in [false, true]) {
    testWidgets(
      '${mine ? 'Own' : 'Received'} message has exactly the allowed actions and six ordered reactions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showMessageActions(context, mine: mine),
                  child: const Text('Open actions'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open actions'));
        await tester.pumpAndSettle();
        final reactions = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(MessageReactionBar),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data)
            .toList();
        expect(reactions, ['❤️', '😆', '😮', '😢', '😠', '👍']);
        for (final label in [
          'Copy',
          'Forward',
          'Reply',
          mine ? 'Delete' : 'Delete for me',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Delete for everyone'), findsNothing);
        expect(find.text('Report'), findsNothing);
        expect(find.text('+'), findsNothing);
        expect(find.text('More'), findsNothing);
      },
    );
  }

  testWidgets(
    'own delete scope closes before confirmation and cancel makes no changes',
    (tester) async {
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final everyone = await chooseDeleteScope(context);
                  if (everyone != null && context.mounted) {
                    applied = await confirmMessageDeletion(
                      context,
                      everyone: everyone,
                    );
                  }
                },
                child: const Text('Delete'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete for me'), findsOneWidget);
      expect(find.text('Delete for everyone'), findsOneWidget);
      await tester.tap(find.text('Delete for me'));
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      expect(find.text('Delete for everyone'), findsNothing);
      expect(find.textContaining('only for you'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(applied, isFalse);
    },
  );

  testWidgets(
    'deleted bubbles and quoted replies never show original content',
    (tester) async {
      final deleted = Message.fromJson({
        'id': 'id',
        'conversation_id': 'chat',
        'sender': 'self',
        'body': 'sensitive old text',
        'attachment': 'old/photo.jpg',
        'created_at': DateTime.now().toIso8601String(),
        'deleted_at': DateTime.now().toIso8601String(),
        'revision': 1,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MessageBubble(
                  message: deleted,
                  mine: true,
                  reactions: const {'friend': '❤️'},
                ),
                QuotedMessagePreview(target: deleted, name: 'Friend'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('You deleted a message'), findsOneWidget);
      expect(find.text('Message removed'), findsOneWidget);
      expect(find.text('sensitive old text'), findsNothing);
      expect(find.text('❤️'), findsNothing);
      expect(deleted.attachment, isNull);
    },
  );

  test('a late snapshot cannot restore globally deleted content', () {
    final now = DateTime.now();
    final old = Message(
      id: 'id',
      conversationId: 'chat',
      sender: 'self',
      body: 'secret',
      createdAt: now,
    );
    final deleted = Message(
      id: 'id',
      conversationId: 'chat',
      sender: 'self',
      createdAt: now,
      deletedAt: now,
      revision: 1,
      forwarded: true,
      replyTo: 'target',
    );
    final result = reconcileMessages([deleted], [old]).single;
    expect(result.deleted, isTrue);
    expect(result.body, isNull);
    expect(result.attachment, isNull);
    expect(result.forwarded, isTrue);
    expect(result.replyTo, 'target');
  });
}
