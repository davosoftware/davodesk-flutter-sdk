import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/pages.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('greets the customer by first name, or "Hi there"', (
    tester,
  ) async {
    final named = await pumpPage(
      tester,
      HomePage.new,
      api: FakeApi()..customerName = 'Chukwu Obi',
    );
    expect(find.text('Hi Chukwu 👋'), findsOneWidget);
    expect(find.text('How can we help?'), findsOneWidget);
    await named.finish(tester);

    final unnamed = await pumpPage(
      tester,
      HomePage.new,
      api: FakeApi()..customerName = null,
    );
    expect(find.text('Hi there 👋'), findsOneWidget);
    await unnamed.finish(tester);
  });

  testWidgets('shows the brand name without a header logo, and Powered by', (
    tester,
  ) async {
    final page = await pumpPage(tester, HomePage.new);
    expect(find.text('Davopay'), findsOneWidget);
    expect(find.text('Powered by DavoDesk'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets('Powered by DavoDesk sits at the bottom of the screen', (
    tester,
  ) async {
    final page = await pumpPage(tester, HomePage.new);
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(find.text('Powered by DavoDesk')).dy,
      greaterThan(screen - 40),
    );
    await page.finish(tester);
  });

  testWidgets('its rows lead to Messages, Help and Send us a message', (
    tester,
  ) async {
    final page = await pumpPage(tester, HomePage.new);
    await tester.tap(find.text('Messages'));
    await tester.tap(find.text('Help'));
    await tester.tap(find.text('Send us a message'));
    expect(page.went, [
      isA<MessagesPlace>(),
      isA<HelpPlace>(),
      isA<EmailPlace>(),
    ]);
    await page.finish(tester);
  });

  testWidgets('opens the channel\'s web links, and only web links', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      HomePage.new,
      api: FakeApi()
        ..configExtras = {
          'appearance': {
            'accent_color': '#1e5af0',
            'home_links': [
              {
                'title': 'Explore Rewards',
                'url': 'https://davopay.test/rewards',
              },
              {'title': 'Run this', 'url': 'javascript:alert(1)'},
            ],
          },
        },
    );
    expect(find.text('Run this'), findsNothing);
    await tester.tap(find.text('Explore Rewards'));
    expect(page.links, [Uri.parse('https://davopay.test/rewards')]);
    await page.finish(tester);
  });

  testWidgets('an open ticket shows as the top card, with who wrote last', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      HomePage.new,
      api: FakeApi()
        ..tickets = [
          ticketJson(
            't1',
            status: 'pending',
            subject: 'Virtual card refund',
            updated: '2026-11-05T10:00:00.000Z',
            lastMessage: {
              'sender_type': 'staff',
              'sender_display_name': 'Mara',
              'preview': 'The refund is back on your card',
            },
          ),
          ticketJson(
            't2',
            status: 'closed',
            subject: 'Old question',
            updated: '2026-11-08T10:00:00.000Z',
          ),
        ],
    );
    expect(find.text('Virtual card refund'), findsOneWidget);
    expect(find.text('Mara: The refund is back on your card'), findsOneWidget);
    expect(find.text('Old question'), findsNothing);
    await tester.tap(find.text('Virtual card refund'));
    expect(page.went, [
      isA<TicketPlace>().having((place) => place.id, 'id', 't1'),
    ]);
    await page.finish(tester);
  });

  testWidgets('a chat waiting for the team shows as the top card', (
    tester,
  ) async {
    final page = await pumpPage(tester, HomePage.new);
    page.sockets.single.trigger('session', {
      'id': 'cs1',
      'status': 'awaiting_human',
      'ticket_id': null,
      'messages': [
        {'id': 'm1', 'sender_type': 'end_user', 'content': 'Where is my card?'},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('Your conversation'), findsOneWidget);
    expect(find.text('You: Where is my card?'), findsOneWidget);
    await tester.tap(find.text('Your conversation'));
    expect(page.went, [isA<ConversationPlace>()]);
    await page.finish(tester);
  });

  testWidgets(
    'no Help row without articles; no team rows when it only answers',
    (tester) async {
      final noArticles = await pumpPage(
        tester,
        HomePage.new,
        api: FakeApi()..articleTotal = 0,
      );
      expect(find.text('Help'), findsNothing);
      expect(find.text('Messages'), findsOneWidget);
      await noArticles.finish(tester);

      final answersOnly = await pumpPage(
        tester,
        HomePage.new,
        api: FakeApi()..supportMode = 'assistant_only',
      );
      expect(find.text('Messages'), findsNothing);
      expect(find.text('Send us a message'), findsNothing);
      expect(find.text('Help'), findsOneWidget);
      expect(answersOnly.sockets, isEmpty);
      await answersOnly.finish(tester);
    },
  );

  testWidgets('nothing overflows at 200 % text, and long titles end in "…"', (
    tester,
  ) async {
    const long =
        'Everything About Your Virtual Dollar Card, Its Fees, Limits, '
        'Top-ups, Freezing and Replacing It When It Is Lost or Stolen';
    final page = await pumpPage(
      tester,
      HomePage.new,
      textScale: 2,
      api: FakeApi()
        ..customerName = 'Chukwuemeka Obiageli'
        ..configExtras = {
          'appearance': {
            'accent_color': '#1e5af0',
            'home_links': [
              {'title': long, 'url': 'https://davopay.test/card'},
            ],
          },
        },
    );
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text(long));
    expect(title.overflow, TextOverflow.ellipsis);
    await page.finish(tester);
  });
}
