import 'package:davodesk_flutter/src/ui/features/conversation/conversation_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  // App feedback spec §7: the page starts a new chat after its first frame.
  test(
    'a new chat draws as new before it starts, so the last one never shows',
    () async {
      final (:client, api: _, :sockets, identities: _) = arrange();
      await client.start();
      sockets.single.trigger('session', {
        'id': 'cs1',
        'status': 'bot',
        'ticket_id': null,
        'messages': [
          {'id': 'm1', 'sender_type': 'bot', 'content': 'The last chat'},
        ],
      });
      await pumpEventQueue();
      expect(client.conversation.value.messages, hasLength(1));

      final model = ConversationViewModel(
        client,
        await client.config(),
        (_) async => null,
        fresh: true,
      );
      expect(model.state.items, isEmpty);
      await model.load();
      expect(model.state.items, isEmpty);
      model.dispose();
      client.dispose();
    },
  );
}
