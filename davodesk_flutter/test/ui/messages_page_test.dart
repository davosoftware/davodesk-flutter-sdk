import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/messages/messages_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/pages.dart';

FakeApi withTickets() => FakeApi()
  ..configExtras = {'ai_agent_name': 'Callie'}
  ..tickets = [
    ticketJson(
      'a00000000000a31f07',
      status: 'resolved',
      subject: 'Withdrawal to my bank account',
      updated: '2026-11-03T10:00:00.000Z',
      lastMessage: {'sender_type': 'end_user', 'preview': 'Thanks, it arrived'},
    ),
    ticketJson(
      '6a0000000000009bbc55',
      status: 'pending',
      subject: 'Virtual card refund',
      updated: '2026-11-05T10:00:00.000Z',
      lastMessage: {
        'sender_type': 'bot',
        'preview': 'Here is how refunds work',
      },
    ),
  ];

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'lists each conversation, newest first, with who wrote last, its state, '
    'reference and an unread dot',
    (tester) async {
      final page = await pumpPage(tester, MessagesPage.new, api: withTickets());
      final refund = tester.getTopLeft(find.text('Virtual card refund'));
      final withdrawal = tester.getTopLeft(
        find.text('Withdrawal to my bank account'),
      );
      expect(refund.dy, lessThan(withdrawal.dy));
      expect(find.text('Callie: Here is how refunds work'), findsOneWidget);
      expect(find.text('You: Thanks, it arrived'), findsOneWidget);
      expect(find.text('Reply · #9BBC55'), findsOneWidget);
      expect(find.text('Solved · #A31F07'), findsOneWidget);
      expect(find.byKey(const Key('unread')), findsNWidgets(2));
      await page.finish(tester);
    },
  );

  testWidgets('opening a ticket marks it seen, and leads to it', (
    tester,
  ) async {
    final page = await pumpPage(tester, MessagesPage.new, api: withTickets());
    await tester.tap(find.text('Virtual card refund'));
    await tester.pumpAndSettle();
    expect(page.went, [
      isA<TicketPlace>().having(
        (place) => place.id,
        'id',
        '6a0000000000009bbc55',
      ),
    ]);
    expect(find.byKey(const Key('unread')), findsOneWidget);
    expect(page.client.unread.value, 1);
    await page.finish(tester);
  });

  testWidgets('the empty state, and Ask a question opening a conversation', (
    tester,
  ) async {
    final page = await pumpPage(tester, MessagesPage.new);
    expect(find.text('No Messages'), findsOneWidget);
    expect(
      find.text('Messages from the team will be shown here'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ask a question'));
    expect(page.went, [
      isA<ConversationPlace>().having((place) => place.fresh, 'fresh', isFalse),
    ]);
    await page.finish(tester);
  });

  testWidgets('the pencil starts a new conversation', (tester) async {
    final page = await pumpPage(tester, MessagesPage.new, api: withTickets());
    await tester.tap(find.bySemanticsLabel('New conversation'));
    expect(page.went, [
      isA<ConversationPlace>().having((place) => place.fresh, 'fresh', isTrue),
    ]);
    await page.finish(tester);
  });

  testWidgets('nothing overflows at 200 % text', (tester) async {
    final page = await pumpPage(
      tester,
      MessagesPage.new,
      api: withTickets(),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await page.finish(tester);
  });
}
