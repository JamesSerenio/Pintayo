import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pintayo/features/friends/application/request_attention.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'viewing Friends clears its badge without clearing Requests or new arrivals',
    () async {
      final state = RequestAttention('alice');
      await state.ready;
      expect(state.count('friends', ['r1', 'r2']), 2);
      await state.mark('friends', ['r1', 'r2']);
      expect(state.count('friends', ['r1', 'r2']), 0);
      expect(state.count('requests', ['r1', 'r2']), 2);
      expect(state.count('friends', ['r1', 'r2', 'r3']), 1);
      await state.mark('requests', ['r1', 'r2']);
      expect(state.count('requests', ['r1', 'r2']), 0);
      state.dispose();
    },
  );

  test(
    'viewed request attention persists across reload and stays account scoped',
    () async {
      final first = RequestAttention('alice');
      await first.ready;
      await first.mark('friends', ['r1']);
      first.dispose();
      final restored = RequestAttention('alice');
      final other = RequestAttention('bob');
      await Future.wait([restored.ready, other.ready]);
      expect(restored.count('friends', ['r1']), 0);
      expect(other.count('friends', ['r1']), 1);
      restored.dispose();
      other.dispose();
    },
  );
}
