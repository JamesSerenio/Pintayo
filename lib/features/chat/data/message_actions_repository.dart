import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/errors/app_exception.dart';

class MessageActionsRepository {
  final SupabaseClient client;
  MessageActionsRepository(this.client);
  Future<void> hide(String message) async {
    await client.rpc('hide_message', params: {'message_id': message});
  }

  Future<void> deleteEveryone(String message) async {
    // The RPC checks sender ownership and atomically redacts the message while
    // queuing attachment removal. A missing cleanup worker must not block it.
    try {
      await client.rpc(
        'delete_message_everyone',
        params: {'message_id': message},
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw const AppException(
          'Chat deletion is not installed on the server. Apply the chat message actions migration.',
        );
      }
      throw const AppException(
        'This message could not be deleted. Only the original sender can delete it for everyone.',
      );
    }
    unawaited(
      _invoke({'action': 'delete_everyone', 'message_id': message}).catchError((
        Object _,
      ) {
        // Supported Storage removal remains queued for the deployed worker.
      }),
    );
  }

  Future<void> forward(String message, String destination, String request) =>
      _invoke({
        'action': 'forward',
        'source_id': message,
        'destination': destination,
        'request_id': request,
      });
  Future<void> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await client.functions.invoke(
        'message-actions',
        body: body,
      );
      if (response.status != 200 || response.data?['ok'] != true) {
        throw const AppException('Message action failed. Please retry.');
      }
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error'] : null;
      if (error.status == 404) {
        throw const AppException(
          'The message-actions server function is not deployed. Deploy it in Supabase to enable this action.',
        );
      }
      throw AppException(
        message is String
            ? message
            : 'Message action could not complete. Check your connection and try again.',
      );
    }
  }
}

final messageActionsRepositoryProvider = Provider(
  (ref) => MessageActionsRepository(ref.watch(supabaseProvider)),
);
