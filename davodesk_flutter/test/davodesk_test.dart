import 'dart:async';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';

/// An app on the framework's Material, with DavoDesk initialized over [api].
Future<
  ({
    BuildContext context,
    FakeApi api,
    List<FakeSocket> sockets,
    List<DavoDeskEvent> events,
  })
>
host(WidgetTester tester, {FakeApi? api, String token = 'ada'}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final (:client, api: fake, :sockets, identities: _) = arrange(
    api: api,
    token: token,
  );
  await DavoDesk.initializeWith(client);
  final events = <DavoDeskEvent>[];
  final listening = DavoDesk.events.listen(events.add);
  addTearDown(listening.cancel);
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (inside) {
          context = inside;
          return const Scaffold(body: Center(child: Text('Acme')));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (context: context, api: fake, sockets: sockets, events: events);
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await DavoDesk.reset();
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('show opens Home, and each page opens its page', (tester) async {
    final (:context, api: _, sockets: _, events: _) = await host(tester);
    final pages = {
      DavoDeskPage.home: 'How can we help?',
      DavoDeskPage.chats: 'No chats yet',
      DavoDeskPage.help: 'Search help articles',
      DavoDeskPage.contact:
          'Have a question about your order or our services? '
          'Our team is here to help.',
    };
    for (final MapEntry(key: page, value: words) in pages.entries) {
      DavoDesk.show(context, page: page);
      await tester.pumpAndSettle();
      expect(find.text(words), findsOneWidget, reason: '$page');
      Navigator.of(context).popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.text('Acme'), findsOneWidget);
    }
    await finish(tester);
  });

  testWidgets('a row on Home leads to its page, and back comes back', (
    tester,
  ) async {
    final (:context, api: _, sockets: _, events: _) = await host(tester);
    DavoDesk.show(context);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat with us'));
    await tester.pumpAndSettle();
    expect(find.text('No chats yet'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('ask opens a conversation and sends the text', (tester) async {
    final (:context, api: _, :sockets, events: _) = await host(tester);
    DavoDesk.ask(context, 'Where is my order?');
    await tester.pumpAndSettle();
    sockets.single.trigger('session', {
      'id': 'cs1',
      'status': 'answers',
      'ticket_id': null,
      'messages': <Object?>[],
    });
    await tester.pumpAndSettle();
    expect(sockets.single.sent, [
      [
        'message',
        {'content': 'Where is my order?'},
      ],
    ]);
    await finish(tester);
  });

  testWidgets('opening support again reads the channel’s look again', (
    tester,
  ) async {
    final (:context, :api, :sockets, events: _) = await host(
      tester,
      api: FakeApi()..configExtras = {'ai_agent_name': 'Callie'},
    );
    // Read once already, for the unread badge; then once per opening.
    final before = api.configReads;
    DavoDesk.ask(context, 'Where is my order?');
    await tester.pumpAndSettle();
    sockets.single.trigger('session', {
      'id': 'cs1',
      'status': 'answers',
      'ticket_id': null,
      'messages': <Object?>[],
    });
    await tester.pumpAndSettle();
    expect(find.text('Callie'), findsOneWidget);
    expect(api.configReads, before + 1);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    // Saved in DavoDesk while the app stays open.
    api.configExtras = {'ai_agent_name': 'Ada'};
    DavoDesk.ask(context, 'And my refund?');
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Callie'), findsNothing);
    expect(api.configReads, before + 2);

    Navigator.of(context).popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    DavoDesk.show(context);
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsOneWidget);
    expect(api.configReads, before + 3);
    await finish(tester);
  });

  testWidgets(
    'a look that cannot be read again opens support with the last one',
    (tester) async {
      final (:context, :api, :sockets, :events) = await host(
        tester,
        api: FakeApi()..configExtras = {'ai_agent_name': 'Callie'},
      );
      api.refuseNextConfig = 503;
      DavoDesk.ask(context, 'Where is my order?');
      await tester.pumpAndSettle();
      sockets.single.trigger('session', {
        'id': 'cs1',
        'status': 'answers',
        'ticket_id': null,
        'messages': <Object?>[],
      });
      await tester.pumpAndSettle();
      expect(find.text('Callie'), findsOneWidget);
      expect(events.whereType<DavoDeskError>(), isEmpty);
      await finish(tester);
    },
  );

  testWidgets(
    'a slow look opens support with the last one, without waiting long',
    (tester) async {
      final (:context, :api, :sockets, events: _) = await host(
        tester,
        api: FakeApi()..configExtras = {'ai_agent_name': 'Callie'},
      );
      final before = api.configReads;
      final slow = api.holdConfig = Completer<void>();
      api.configExtras = {'ai_agent_name': 'Ada'};
      DavoDesk.ask(context, 'Where is my order?');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Callie'), findsOneWidget);

      // The read lands for next time, and the open page waited on it rather than asking again.
      slow.complete();
      api.holdConfig = null;
      await tester.pumpAndSettle();
      expect(api.configReads, before + 1);
      sockets.single.trigger('session', {
        'id': 'cs1',
        'status': 'answers',
        'ticket_id': null,
        'messages': <Object?>[],
      });
      await tester.pumpAndSettle();
      await finish(tester);
    },
  );

  testWidgets('openTicket opens that ticket', (tester) async {
    final (:context, api: _, sockets: _, events: _) = await host(
      tester,
      api: FakeApi()
        ..ticketsById = {
          't1': ticketJson('t1', subject: 'Virtual card refund'),
        },
    );
    DavoDesk.openTicket(context, 't1');
    await tester.pumpAndSettle();
    expect(find.text('Virtual card refund'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the events: opened and closed, unread, and a raised ticket', (
    tester,
  ) async {
    final (:context, :api, :sockets, :events) = await host(
      tester,
      api: FakeApi()
        ..tickets = [ticketJson('t0', updated: '2026-11-05T10:00:00.000Z')],
    );
    // Read at initialize, for the badge before support is first opened.
    expect(DavoDesk.unread.value, 1);

    api.tickets = [
      ...api.tickets,
      ticketJson('t1', updated: '2026-11-06T10:00:00.000Z'),
    ];
    DavoDesk.show(context);
    await tester.pumpAndSettle();
    expect(events.whereType<DavoDeskOpened>(), hasLength(1));
    expect(
      events,
      contains(isA<DavoDeskUnread>().having((e) => e.count, 'count', 2)),
    );

    sockets.single.trigger('handoff', {
      'ticket_id': '6a0000000000009bbc55',
      'resumed': false,
      'reason': 'customer_requested',
    });
    await tester.pumpAndSettle();
    expect(
      events.whereType<DavoDeskTicketRaised>().single,
      isA<DavoDeskTicketRaised>()
          .having((e) => e.id, 'id', '6a0000000000009bbc55')
          .having((e) => e.reference, 'reference', '#9BBC55'),
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(events.whereType<DavoDeskClosed>(), hasLength(1));
    await finish(tester);
  });

  testWidgets('a refused identity token is an error event, once', (
    tester,
  ) async {
    final (context: _, api: _, sockets: _, :events) = await host(
      tester,
      token: '',
    );
    expect(
      events.whereType<DavoDeskError>().single,
      isA<DavoDeskError>().having((e) => e.code, 'code', 'TOKEN_FAILED'),
    );
    await finish(tester);
  });

  testWidgets(
    'logout pops the support routes, clears unread, and ends the session',
    (tester) async {
      final (:context, :api, sockets: _, :events) = await host(
        tester,
        api: FakeApi()
          ..tickets = [ticketJson('t0', updated: '2026-11-05T10:00:00.000Z')],
      );
      DavoDesk.show(context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat with us'));
      await tester.pumpAndSettle();

      await DavoDesk.logout();
      await tester.pumpAndSettle();
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('How can we help?'), findsNothing);
      expect(DavoDesk.unread.value, 0);
      expect(api.loggedOut, isTrue);
      expect(events.whereType<DavoDeskClosed>(), hasLength(1));
      await finish(tester);
    },
  );

  test('a call before initialize throws', () async {
    await DavoDesk.reset();
    expect(
      () => DavoDesk.unread,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Call DavoDesk.initialize first.',
        ),
      ),
    );
    expect(DavoDesk.logout, throwsStateError);
  });
}
