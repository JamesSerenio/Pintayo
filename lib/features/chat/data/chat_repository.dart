import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../profile/data/models/profile.dart';
import '../../profile/data/profile_repository.dart';
import 'models/message.dart';

class Conversation {
  final String id, preview;
  final Profile? friend;
  final int unread;
  final DateTime? updatedAt;
  const Conversation(
    this.id,
    this.preview,
    this.friend,
    this.unread,
    this.updatedAt,
  );
}

class ChatRepository {
  final SupabaseClient client;
  final ProfileRepository profiles;
  final ConnectivityService connectivity;
  ChatRepository(this.client, this.profiles, this.connectivity);
  String get userId => client.auth.currentUser!.id;
  Future<String> open(String friend) async =>
      await client.rpc('open_chat', params: {'friend': friend}) as String;
  Future<List<Conversation>> conversations() async {
    final rows = await client.rpc('chat_summaries');
    return Future.wait(
      (rows as List).map(
        (r) async => Conversation(
          r['id'],
          r['preview'],
          await profiles.person(r['friend_id']),
          (r['unread'] as num).toInt(),
          DateTime.tryParse(r['last_message_at'] ?? ''),
        ),
      ),
    );
  }

  Future<Profile?> partner(String chat) async {
    final row = await client
        .from('conversations')
        .select()
        .eq('id', chat)
        .single();
    return profiles.person(row['a'] == userId ? row['b'] : row['a']);
  }

  Future<List<Message>> page(String chat, {Message? before}) async => _decode(
    await client.rpc(
      'message_page',
      params: {
        'chat': chat,
        'before_time': before?.createdAt.toUtc().toIso8601String(),
        'before_id': before?.id,
      },
    ),
  );
  Future<List<Message>> since(String chat, Message cursor) async => _decode(
    await client.rpc(
      'messages_since',
      params: {
        'chat': chat,
        'since_time': cursor.createdAt.toUtc().toIso8601String(),
        'since_id': cursor.id,
      },
    ),
  );
  List<Message> _decode(dynamic rows) => (rows as List)
      .map((r) => Message.fromJson(Map<String, dynamic>.from(r)))
      .toList();
  Future<void> send(String chat, String id, String? body, String? photo) async {
    if (!await connectivity.isConnected) {
      throw const AppException('You’re offline. Connect to send.');
    }
    await client
        .rpc(
          'send_message',
          params: {
            'message_id': id,
            'chat': chat,
            'body_text': body,
            'photo': photo,
          },
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> acknowledge(
    String chat, {
    bool seen = false,
    required List<String> ids,
  }) async {
    for (var offset = 0; offset < ids.length; offset += 500) {
      await client.rpc(
        'ack_received',
        params: {
          'chat': chat,
          'seen': seen,
          'message_ids': ids.skip(offset).take(500).toList(),
        },
      );
    }
  }

  Future<List<Message>> refreshReceipts(String chat, List<String> ids) async {
    final result = <Message>[];
    for (var offset = 0; offset < ids.length; offset += 500) {
      result.addAll(
        _decode(
          await client.rpc(
            'message_receipts',
            params: {
              'chat': chat,
              'message_ids': ids.skip(offset).take(500).toList(),
            },
          ),
        ),
      );
    }
    return result;
  }
}

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(
    ref.watch(supabaseProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(connectivityServiceProvider),
  ),
);
final conversationsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(chatRepositoryProvider).conversations(),
);
final chatPartnerProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(chatRepositoryProvider).partner(id),
);
