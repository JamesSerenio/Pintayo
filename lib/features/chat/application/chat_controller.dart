import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../../shared/widgets/private_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../profile/data/image_upload_service.dart';
import '../data/chat_repository.dart';
import '../data/models/message.dart';

class FailedMessage {
  final String id;
  final String? text, photo, replyTo;
  const FailedMessage(this.id, this.text, this.photo, [this.replyTo]);
}

class ChatController extends ChangeNotifier {
  final String conversation;
  final ChatRepository repository;
  final ImageUploadService uploads;
  final ConnectivityService connectivity;
  final void Function(String)? onAttachmentRevoked;
  List<Message> messages = [];
  final Map<String, Message> replyTargets = {};
  final Set<String> _hiddenIds = {};
  void _merge(Iterable<Message> incoming) {
    messages = reconcileMessages(
      messages,
      incoming,
    ).where((m) => !_hiddenIds.contains(m.id)).toList();
  }

  Message? replyingTo;
  void reply(Message? message) {
    replyingTo = message;
    _notify();
  }

  List<FailedMessage> failed = [];
  bool loading = true,
      sending = false,
      hasOlder = true,
      active = true,
      _disposed = false;
  String? error;
  late final RealtimeChannel _channel;
  StreamSubscription<bool>? _network;
  bool _catchingUp = false, _again = false;
  Timer? _refreshTimer;
  ChatController(
    this.conversation,
    this.repository,
    this.uploads,
    this.connectivity, {
    this.onAttachmentRevoked,
  }) {
    _channel =
        repository.client
            .channel('messages:$conversation')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversation,
              ),
              callback: (event) {
                if (_disposed || event.newRecord.isEmpty) return;
                final old =
                    messages
                        .where((m) => m.id == event.newRecord['id'])
                        .firstOrNull ??
                    replyTargets[event.newRecord['id']];
                if (event.newRecord['deleted_at'] != null &&
                    old?.attachment != null) {
                  onAttachmentRevoked?.call(old!.attachment!);
                }
                _merge([Message.fromJson(event.newRecord)]);
                failed.removeWhere((f) => f.id == event.newRecord['id']);
                if (event.newRecord['deleted_at'] != null) {
                  replyTargets[event.newRecord['id']] = Message.fromJson(
                    event.newRecord,
                  );
                  if (replyingTo?.id == event.newRecord['id']) {
                    replyingTo = null;
                  }
                }
                catchUp();
                _ack();
                _notify();
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'hidden_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'owner',
                value: repository.userId,
              ),
              callback: (event) {
                if (_disposed || event.newRecord.isEmpty) return;
                final id = event.newRecord['message_id'];
                if (id is String) _hiddenIds.add(id);
                final old =
                    messages.where((m) => m.id == id).firstOrNull ??
                    replyTargets[id];
                if (old?.attachment != null) {
                  onAttachmentRevoked?.call(old!.attachment!);
                }
                messages.removeWhere((m) => m.id == id);
                replyTargets.remove(id);
                if (replyingTo?.id == id) replyingTo = null;
                _notify();
                catchUp();
              },
            )
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) catchUp();
          });
    _network = connectivity.changes.listen((online) {
      if (online) catchUp();
    });
    catchUp();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (active) catchUp();
    });
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _ack() async {
    try {
      await repository.acknowledge(
        conversation,
        seen: active,
        ids: messages.map((m) => m.id).toList(),
      );
    } catch (_) {
      /* Retry after reconnect. */
    }
  }

  Future<void> catchUp() async {
    if (_disposed) return;
    if (_catchingUp) {
      _again = true;
      return;
    }
    _catchingUp = true;
    try {
      if (messages.isNotEmpty) {
        var cursor = messages.last;
        while (!_disposed) {
          final batch = await repository.since(conversation, cursor);
          _merge(batch);
          if (batch.length < 200) break;
          cursor = batch.last;
        }
      }
      // Also reconcile receipts and the initial newest page.
      _merge(await repository.page(conversation));
      await _refreshVisible();
      failed.removeWhere((f) => messages.any((m) => m.id == f.id));
      await _ack();
      error = null;
    } catch (e) {
      error = readableError(e);
    }
    loading = false;
    _catchingUp = false;
    _notify();
    if (_again && !_disposed) {
      _again = false;
      catchUp();
    }
  }

  Future<void> _refreshVisible() async {
    final requested = messages.map((m) => m.id).toSet();
    final current = await repository.refreshReceipts(
      conversation,
      requested.toList(),
    );
    if (_disposed) return;
    final visible = current.map((m) => m.id).toSet();
    _hiddenIds.addAll(requested.difference(visible));
    for (final old in [...messages, ...replyTargets.values]) {
      final fresh = current.where((m) => m.id == old.id).firstOrNull;
      if (old.attachment != null &&
          requested.contains(old.id) &&
          (fresh == null || fresh.deleted)) {
        onAttachmentRevoked?.call(old.attachment!);
      }
    }
    messages = reconcileMessages(messages, current)
        .where(
          (m) =>
              !_hiddenIds.contains(m.id) &&
              (!requested.contains(m.id) || visible.contains(m.id)),
        )
        .toList();
    final refs = messages.map((m) => m.replyTo).whereType<String>().toSet();
    final targets = await repository.refreshReceipts(
      conversation,
      refs.toList(),
    );
    if (_disposed) return;
    final targetIds = targets.map((m) => m.id).toSet();
    final mergedTargets = reconcileMessages(replyTargets.values, targets)
        .where((m) => targetIds.contains(m.id) && !_hiddenIds.contains(m.id))
        .toList();
    for (final old in replyTargets.values) {
      final latest = mergedTargets.where((m) => m.id == old.id).firstOrNull;
      if (old.attachment != null && (latest == null || latest.deleted)) {
        onAttachmentRevoked?.call(old.attachment!);
      }
    }
    replyTargets
      ..clear()
      ..addEntries(mergedTargets.map((m) => MapEntry(m.id, m)));
    if (replyingTo != null) {
      final latest = current.where((m) => m.id == replyingTo!.id).firstOrNull;
      if (latest == null || latest.deleted) replyingTo = null;
    }
  }

  Future<void> older() async {
    if (messages.isEmpty || !hasOlder) return;
    try {
      final batch = await repository.page(conversation, before: messages.first);
      hasOlder = batch.length == 40;
      _merge(batch);
      await _refreshVisible();
      await _ack();
    } catch (e) {
      error = readableError(e);
    }
    _notify();
  }

  Future<void> send({
    String? text,
    bool photo = false,
    FailedMessage? retry,
  }) async {
    if (sending) return;
    sending = true;
    error = null;
    _notify();
    var pending =
        retry ??
        FailedMessage(const Uuid().v4(), text?.trim(), null, replyingTo?.id);
    try {
      if (photo) {
        final path = await uploads.selectAndUpload(
          'attachments',
          conversation: conversation,
        );
        if (path == null) return;
        pending = FailedMessage(
          pending.id,
          pending.text,
          path,
          pending.replyTo,
        );
      }
      await repository.send(
        conversation,
        pending.id,
        pending.text,
        pending.photo,
        replyTo: pending.replyTo,
      );
      failed.removeWhere((f) => f.id == pending.id);
      replyingTo = null;
      await catchUp();
    } catch (e) {
      failed.removeWhere((f) => f.id == pending.id);
      failed.add(pending);
      error = '${readableError(e)} Tap retry to send again.';
    } finally {
      sending = false;
      _notify();
    }
  }

  void setActive(bool value) {
    active = value;
    if (value) {
      catchUp();
      _ack();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _network?.cancel();
    _refreshTimer?.cancel();
    repository.client.removeChannel(_channel);
    super.dispose();
  }
}

final chatControllerProvider = Provider.autoDispose
    .family<ChatController, String>((ref, id) {
      final controller = ChatController(
        id,
        ref.watch(chatRepositoryProvider),
        ref.watch(imageUploadProvider),
        ref.watch(connectivityServiceProvider),
        onAttachmentRevoked: (path) {
          final key = ('attachments', path);
          final url = ref.read(signedImageProvider(key)).asData?.value;
          if (url != null) NetworkImage(url).evict();
          ref.invalidate(signedImageProvider(key));
        },
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
