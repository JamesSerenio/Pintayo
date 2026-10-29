// Explicit opt-in. Run ONLY against a disposable development Supabase project.
// No admin credential is compiled into this test or the mobile application.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const enabled = bool.fromEnvironment('RUN_BACKEND_TESTS');
const url = String.fromEnvironment('TEST_SUPABASE_URL');
const key = String.fromEnvironment('TEST_SUPABASE_KEY');

void main() {
  test(
    'authorization, open-channel revocation, persistence, receipts and catch-up',
    () async {
      final clients = List.generate(3, (_) => SupabaseClient(url, key));
      final a = clients[0], b = clients[1], c = clients[2];
      addTearDown(() async {
        for (final client in clients) {
          await client.dispose();
        }
      });
      final credentials = [
        (
          const String.fromEnvironment('TEST_A_EMAIL'),
          const String.fromEnvironment('TEST_A_PASSWORD'),
        ),
        (
          const String.fromEnvironment('TEST_B_EMAIL'),
          const String.fromEnvironment('TEST_B_PASSWORD'),
        ),
        (
          const String.fromEnvironment('TEST_C_EMAIL'),
          const String.fromEnvironment('TEST_C_PASSWORD'),
        ),
      ];
      for (var i = 0; i < clients.length; i++) {
        await clients[i].auth.signInWithPassword(
          email: credentials[i].$1,
          password: credentials[i].$2,
        );
        final uid = clients[i].auth.currentUser!.id;
        final exists = await clients[i]
            .from('profiles')
            .select('id')
            .eq('id', uid)
            .maybeSingle();
        if (exists == null) {
          await clients[i].from('profiles').insert({
            'id': uid,
            'username': 'test_${uid.replaceAll('-', '').substring(0, 16)}',
            'display_name': 'Development test ${i + 1}',
            'onboarded': true,
          });
        }
      }
      final aid = a.auth.currentUser!.id, bid = b.auth.currentUser!.id;
      Future<void> friend(
        SupabaseClient client,
        String target,
        String action,
      ) async => client.rpc(
        'friend_action',
        params: {'target_id': target, 'action': action},
      );
      await friend(a, bid, 'unblock');
      await friend(b, aid, 'unblock');
      await friend(a, bid, 'remove');
      await friend(a, bid, 'cancel');
      await friend(b, aid, 'cancel');
      await expectLater(
        friend(a, aid, 'request'),
        throwsA(isA<PostgrestException>()),
      );
      await friend(a, bid, 'request');
      await friend(a, bid, 'request');
      final requests = await b
          .from('friendships')
          .select()
          .eq('requester', aid)
          .eq('recipient', bid);
      expect(requests, hasLength(1));
      await friend(b, aid, 'accept');
      await a.rpc(
        'share_start',
        params: {
          'friends': [bid],
          'circles': <String>[],
          'minutes': 15,
        },
      );
      final received = <Map<String, dynamic>>[];
      final subscribed = Completer<void>();
      final channel =
          b
              .channel('revocation-test-${const Uuid().v4()}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'location_inbox',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'recipient',
                  value: bid,
                ),
                callback: (event) {
                  if (event.newRecord.isNotEmpty) received.add(event.newRecord);
                },
              )
            ..subscribe((status, _) {
              if (status == RealtimeSubscribeStatus.subscribed &&
                  !subscribed.isCompleted) {
                subscribed.complete();
              }
            });
      await subscribed.future.timeout(const Duration(seconds: 15));
      Future<void> fix(double latitude) async => a.rpc(
        'publish_location',
        params: {
          'lat': latitude,
          'lng': 121.0,
          'accuracy_m': 15,
          'fix_time': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await fix(14.51);
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (received.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(
        received,
        isNotEmpty,
        reason:
            'A positive delivery control must pass before testing revocation',
      );
      expect(await c.from('location_inbox').select(), isEmpty);
      expect(
        await b.from('latest_locations').select().eq('owner', aid),
        isEmpty,
      );

      // Leave this exact channel open; do not resubscribe after revocation.
      await friend(b, aid, 'remove');
      final atRevocation = received.length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await fix(14.52);
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(
        received.length,
        atRevocation,
        reason: 'Open realtime channel must not receive any new coordinates',
      );
      expect(await b.from('location_inbox').select().eq('owner', aid), isEmpty);
      await b.removeChannel(channel);
      await a.rpc('share_state', params: {'new_state': 'stopped'});

      await friend(a, bid, 'request');
      await friend(b, aid, 'accept');
      final chat = await a.rpc('open_chat', params: {'friend': bid});
      final id = const Uuid().v4();
      final payload = {
        'message_id': id,
        'chat': chat,
        'body_text': 'Development persistence test',
        'photo': null,
      };
      await a.rpc('send_message', params: payload);
      await a.rpc('send_message', params: payload);
      final persisted = await a.from('messages').select().eq('id', id);
      expect(persisted, hasLength(1));
      expect(persisted.single['delivered_at'], isNull);
      expect(persisted.single['seen_at'], isNull);
      await expectLater(
        c.rpc(
          'send_message',
          params: {...payload, 'message_id': const Uuid().v4()},
        ),
        throwsA(isA<PostgrestException>()),
      );
      final attachment = '$chat/$aid/security-fixture.jpg';
      await expectLater(
        c.storage
            .from('attachments')
            .uploadBinary(
              attachment,
              Uint8List.fromList([255, 216, 255, 217]),
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            ),
        throwsA(isA<StorageException>()),
      );
      // A fresh authenticated connection has no realtime message memory.
      final reconnected = SupabaseClient(url, key);
      addTearDown(reconnected.dispose);
      await reconnected.auth.signInWithPassword(
        email: credentials[1].$1,
        password: credentials[1].$2,
      );
      final catchup = await reconnected.rpc(
        'message_page',
        params: {'chat': chat},
      );
      expect((catchup as List).any((m) => m['id'] == id), isTrue);
      await b.rpc(
        'ack_received',
        params: {
          'chat': chat,
          'message_ids': [id],
          'seen': false,
        },
      );
      var row = await a.from('messages').select().eq('id', id).single();
      expect(row['delivered_at'], isNotNull);
      expect(row['seen_at'], isNull);
      await b.rpc(
        'ack_received',
        params: {
          'chat': chat,
          'message_ids': [id],
          'seen': true,
        },
      );
      row = await a.from('messages').select().eq('id', id).single();
      expect(row['seen_at'], isNotNull);
      await friend(b, aid, 'block');
      await expectLater(
        a.rpc(
          'send_message',
          params: {...payload, 'message_id': const Uuid().v4()},
        ),
        throwsA(isA<PostgrestException>()),
      );
      final search = await a.rpc('search_people', params: {'query': bid});
      expect(search, isEmpty, reason: 'Blocked users cannot be discovered');
      await friend(b, aid, 'unblock');
    },
    skip: !enabled
        ? 'Requires disposable Supabase project and three confirmed test accounts.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
