enum MessageReceipt { sent, delivered, seen }

class Message {
  final String id, conversationId, sender;
  final String? body, attachment;
  final DateTime createdAt;
  final DateTime? deliveredAt, seenAt, deletedAt;
  final String? replyTo;
  final bool forwarded;
  final int revision;
  const Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    this.body,
    this.attachment,
    required this.createdAt,
    this.deliveredAt,
    this.seenAt,
    this.deletedAt,
    this.replyTo,
    this.forwarded = false,
    this.revision = 0,
  });
  bool get deleted => deletedAt != null;
  MessageReceipt get receipt => seenAt != null
      ? MessageReceipt.seen
      : deliveredAt != null
      ? MessageReceipt.delivered
      : MessageReceipt.sent;
  factory Message.fromJson(Map<String, dynamic> row) => Message(
    id: row['id'],
    conversationId: row['conversation_id'],
    sender: row['sender'],
    body: row['deleted_at'] == null ? row['body'] : null,
    attachment: row['deleted_at'] == null ? row['attachment'] : null,
    createdAt: DateTime.parse(row['created_at']),
    deliveredAt: DateTime.tryParse(row['delivered_at'] ?? ''),
    seenAt: DateTime.tryParse(row['seen_at'] ?? ''),
    deletedAt: DateTime.tryParse(row['deleted_at'] ?? ''),
    replyTo: row['reply_to'],
    forwarded: row['forwarded'] ?? false,
    revision: (row['revision'] as num?)?.toInt() ?? 0,
  );
}

List<Message> reconcileMessages(
  Iterable<Message> current,
  Iterable<Message> incoming,
) {
  final byId = {for (final m in current) m.id: m};
  for (final message in incoming) {
    final old = byId[message.id];
    if (old != null &&
        (old.revision > message.revision ||
            (old.deleted && !message.deleted))) {
      continue;
    }
    // Reconnect snapshots cannot regress already-acknowledged receipts.
    byId[message.id] = Message(
      id: message.id,
      conversationId: message.conversationId,
      sender: message.sender,
      body: message.body,
      attachment: message.attachment,
      createdAt: message.createdAt,
      deletedAt: message.deletedAt,
      replyTo: message.replyTo,
      forwarded: message.forwarded,
      revision: message.revision,
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
