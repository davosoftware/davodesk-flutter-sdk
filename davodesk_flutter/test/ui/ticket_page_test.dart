import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/ticket/ticket_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/pages.dart';

const id = '6a0000000000009bbc55';

FakeApi withTicket(Map<String, Object?> extra) => FakeApi()
  ..configExtras = {'ai_agent_name': 'Callie'}
  ..ticketsById = {
    id: {
      ...ticketJson(id, subject: 'Virtual card refund', status: 'pending'),
      'messages': [
        {
          'id': 'm1',
          'sender_type': 'end_user',
          'content': 'Where is my refund?',
        },
        {'id': 'm2', 'sender_type': 'bot', 'content': 'Refunds take 3 days.'},
        {
          'id': 'm3',
          'sender_type': 'staff',
          'sender_display_name': 'Mara',
          'content': 'It is back on your card.',
        },
      ],
      ...extra,
    },
  };

Future<PageHarness> openTicket(WidgetTester tester, FakeApi api) =>
    pumpPage(tester, () => const TicketPage(id: id), api: api);

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('the subject, its state chip, and its messages with names', (
    tester,
  ) async {
    final page = await openTicket(tester, withTicket({}));
    expect(find.text('Virtual card refund'), findsOneWidget);
    expect(find.text('Reply · #9BBC55'), findsOneWidget);
    expect(find.text('Where is my refund?'), findsOneWidget);
    expect(find.text('Callie · AI Agent'), findsOneWidget);
    expect(find.text('Mara'), findsOneWidget);
    expect(find.text('How was the help?'), findsNothing);
    expect(find.text('Reopen it'), findsNothing);
    await tester.tap(find.text('Continue the conversation'));
    expect(page.went, [isA<ConversationPlace>()]);
    await page.finish(tester);
  });

  testWidgets('the rating only when asked: Good or Bad, a comment, then Send', (
    tester,
  ) async {
    final page = await openTicket(
      tester,
      withTicket({
        'status': 'resolved',
        'satisfaction': {
          'requested_at': '2026-11-05T10:00:00.000Z',
          'rating': null,
        },
      }),
    );
    expect(find.text('How was the help?'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Quick, thanks');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    final (ticket, body) = page.api.rated.single;
    expect(ticket, id);
    expect(body, {'rating': 'good', 'comment': 'Quick, thanks'});
    expect(find.text('How was the help?'), findsNothing);
    await page.finish(tester);
  });

  testWidgets('Reopen it only when it can be reopened', (tester) async {
    final page = await openTicket(
      tester,
      withTicket({'status': 'resolved', 'reopenable': true}),
    );
    await tester.tap(find.text('Reopen it'));
    await tester.pumpAndSettle();
    expect(page.api.reopened, [id]);
    expect(find.text('Reopen it'), findsNothing);
    expect(find.text('Open · #9BBC55'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets(
    'a closed ticket shows the closed line, and Start a new conversation',
    (tester) async {
      final page = await openTicket(tester, withTicket({'status': 'closed'}));
      expect(find.text('This conversation was closed.'), findsOneWidget);
      expect(find.text('Continue the conversation'), findsNothing);
      await tester.tap(find.text('Start a new conversation'));
      expect(page.went, [
        isA<ConversationPlace>().having(
          (place) => place.fresh,
          'fresh',
          isTrue,
        ),
      ]);
      await page.finish(tester);
    },
  );

  testWidgets('a merged ticket opens the ticket it was merged into', (
    tester,
  ) async {
    final api =
        withTicket({'merged_into': 'b00000000000b0b0b0', 'status': 'closed'})
          ..ticketsById['b00000000000b0b0b0'] = ticketJson(
            'b00000000000b0b0b0',
            subject: 'Refunds, all in one place',
          );
    final page = await openTicket(tester, api);
    expect(find.text('Refunds, all in one place'), findsOneWidget);
    expect(find.text('Virtual card refund'), findsNothing);
    await page.finish(tester);
  });
}
