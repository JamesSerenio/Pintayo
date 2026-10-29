import 'dart:async';
import 'package:flutter/foundation.dart';
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
  final String? text, photo;
  const FailedMessage(this.id, this.text, this.photo);
}

class ChatController extends ChangeNotifier {
  final String conversation;
  final ChatRepository repository;
  final ImageUploadService uploads;
  final ConnectivityService connectivity;
  List<Message> messages = [];
  List<FailedMessage> failed = [];
  bool loading = true,
      sending = false,
      hasOlder = true,
      active = true,
      _disposed = false;
  String? error;
  late final RealtimeChannel _channel;
  StreamSubscription<bool>? _network;
  bool _catchingUp = false;
  ChatController(
    this.conversation,
    this.repository,
    this.uploads,
    this.connectivity,
  ) {
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
                messages = reconcileMessages(messages, [
                  Message.fromJson(event.newRecord),
                ]);
                failed.removeWhere((f) => f.id == event.newRecord['id']);
                _ack();
                _notify();
              },
            )
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) catchUp();
          });
    _network = connectivity.changes.listen((online) {
      if (online) catchUp();
    });
    catchUp();
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
    if (_catchingUp || _disposed) return;
    _catchingUp = true;
    try {
      if (messages.isNotEmpty) {
        var cursor = messages.last;
        while (!_disposed) {
          final batch = await repository.since(conversation, cursor);
          messages = reconcileMessages(messages, batch);
          if (batch.length < 200) break;
          cursor = messages.last;
        }
      }
      // Also reconcile receipts and the initial newest page.
      messages = reconcileMessages(
        messages,
        await repository.page(conversation),
      );
      messages = reconcileMessages(
        messages,
        await repository.refreshReceipts(
          conversation,
          messages.map((m) => m.id).toList(),
        ),
      );
      failed.removeWhere((f) => messages.any((m) => m.id == f.id));
      await _ack();
      error = null;
    } catch (e) {
      error = readableError(e);
    }
    loading = false;
    _catchingUp = false;
    _notify();
  }

  Future<void> older() async {
    if (messages.isEmpty || !hasOlder) return;
    try {
      final batch = await repository.page(conversation, before: messages.first);
      hasOlder = batch.length == 40;
      messages = reconcileMessages(messages, batch);
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
    var pending = retry ?? FailedMessage(const Uuid().v4(), text?.trim(), null);
    try {
      if (photo) {
        final path = await uploads.selectAndUpload(
          'attachments',
          conversation: conversation,
        );
        if (path == null) return;
        pending = FailedMessage(pending.id, null, path);
      }
      await repository.send(
        conversation,
        pending.id,
        pending.text,
        pending.photo,
      );
      failed.removeWhere((f) => f.id == pending.id);
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
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
