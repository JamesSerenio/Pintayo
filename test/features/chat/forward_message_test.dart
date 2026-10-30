import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pintayo/core/errors/app_exception.dart';
import 'package:pintayo/features/chat/data/chat_repository.dart';
import 'package:pintayo/features/chat/data/message_actions_repository.dart';
import 'package:pintayo/features/chat/presentation/widgets/forward_message_sheet.dart';
import 'package:pintayo/features/friends/data/friends_repository.dart';
import 'package:pintayo/features/profile/data/models/profile.dart';

class _Chat implements ChatRepository {
  @override
  Future<String> open(String friend) async => 'destination';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions implements MessageActionsRepository {
  final first = Completer<void>();
  final List<String> requests = [];
  @override
  Future<void> forward(
    String message,
    String destination,
    String request,
  ) async {
    requests.add(request);
    if (requests.length == 1) await first.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'forward picker searches eligible friends, guards repeated taps, and retries with the same operation ID',
    (tester) async {
      final actions = _Actions();
      const accepted = Friendship(
        'friendship',
        Profile(
          id: 'friend',
          username: 'eligible',
          displayName: 'Eligible Friend',
        ),
        accepted: true,
        incoming: true,
      );
      const pending = Friendship(
        'pending',
        Profile(
          id: 'pending',
          username: 'pending',
          displayName: 'Pending Person',
        ),
        accepted: false,
        incoming: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            friendsProvider.overrideWith((ref) async => [accepted, pending]),
            chatRepositoryProvider.overrideWithValue(_Chat()),
            messageActionsRepositoryProvider.overrideWithValue(actions),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        const ForwardMessageSheet(message: 'source'),
                  ),
                  child: const Text('Open forwarding'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open forwarding'));
      await tester.pumpAndSettle();
      expect(find.text('Eligible Friend'), findsOneWidget);
      expect(find.text('Pending Person'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'ELIGIBLE');
      await tester.pump();
      await tester.tap(find.text('Eligible Friend'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Forward'));
      await tester.pump();
      expect(actions.requests.length, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      actions.first.completeError(const AppException('Temporary test failure'));
      await tester.pumpAndSettle();
      expect(find.text('Temporary test failure'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Forward'));
      await tester.pumpAndSettle();
      expect(actions.requests.length, 2);
      expect(actions.requests[0], actions.requests[1]);
      expect(find.byType(ForwardMessageSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
