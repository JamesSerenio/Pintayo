import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/features/chat/data/models/message.dart';

Message message(String id, int second, {DateTime? delivered, DateTime? seen}) =>
    Message(
      id: id,
      conversationId: 'chat',
      sender: 'sender',
      body: id,
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, second),
      deliveredAt: delivered,
      seenAt: seen,
    );
void main() {
  test(
    'overlapping reconnect pages deduplicate and preserve receipt progress',
    () {
      final seen = DateTime.utc(2026, 1, 2);
      final result = reconcileMessages(
        [message('b', 2, delivered: seen, seen: seen), message('a', 1)],
        [message('b', 2), message('c', 3), message('a', 1)],
      );
      expect(result.map((m) => m.id), ['a', 'b', 'c']);
      expect(result[1].receipt, MessageReceipt.seen);
      expect(result[2].receipt, MessageReceipt.sent);
    },
  );
  test(
    'delivery requires recipient acknowledgement, seen requires reading',
    () {
      final now = DateTime.now();
      expect(message('a', 0).receipt, MessageReceipt.sent);
      expect(message('a', 0, delivered: now).receipt, MessageReceipt.delivered);
      expect(
        message('a', 0, delivered: now, seen: now).receipt,
        MessageReceipt.seen,
      );
    },
  );
}
