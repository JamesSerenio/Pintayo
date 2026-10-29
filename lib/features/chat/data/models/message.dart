enum MessageReceipt { sent, delivered, seen }

class Message {
  final String id, conversationId, sender;
  final String? body, attachment;
  final DateTime createdAt;
  final DateTime? deliveredAt, seenAt;
  const Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    this.body,
    this.attachment,
    required this.createdAt,
    this.deliveredAt,
    this.seenAt,
  });
  MessageReceipt get receipt => seenAt != null
      ? MessageReceipt.seen
      : deliveredAt != null
      ? MessageReceipt.delivered
      : MessageReceipt.sent;
  factory Message.fromJson(Map<String, dynamic> row) => Message(
    id: row['id'],
    conversationId: row['conversation_id'],
    sender: row['sender'],
    body: row['body'],
    attachment: row['attachment'],
    createdAt: DateTime.parse(row['created_at']),
    deliveredAt: DateTime.tryParse(row['delivered_at'] ?? ''),
    seenAt: DateTime.tryParse(row['seen_at'] ?? ''),
  );
}

List<Message> reconcileMessages(
  Iterable<Message> current,
  Iterable<Message> incoming,
) {
  final byId = {for (final m in current) m.id: m};
  for (final message in incoming) {
    final old = byId[message.id];
    // Reconnect snapshots cannot regress already-acknowledged receipts.
    byId[message.id] = Message(
      id: message.id,
      conversationId: message.conversationId,
      sender: message.sender,
      body: message.body,
      attachment: message.attachment,
      createdAt: message.createdAt,
      deliveredAt: message.deliveredAt ?? old?.deliveredAt,
      seenAt: message.seenAt ?? old?.seenAt,
    );
  }
  final result = byId.values.toList()
    ..sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
  return result;
}
