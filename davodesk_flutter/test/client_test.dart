import 'dart:convert';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_api.dart';

const uuidV4 =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    "reads the config once, and Home's name and help centre from the session",
    () async {
      final (:client, :api, sockets: _, :identities) = arrange();
      await client.start();
      expect((await client.config()).brandName, 'Davopay');
      await client.config();
      expect(api.configReads, 1);
      expect(client.customerName, 'Ada Lovelace');
      expect(await client.hasHelpCentre(), isTrue);
      expect(await client.hasHelpCentre(), isTrue);
      expect(api.articleReads, 1);
      expect(identities(), 1);
      client.dispose();
    },
  );

  test('the conversation follows the chat, and startNew begins anew', () async {
    final (:client, api: _, :sockets, identities: _) = arrange();
    await client.start();
    sockets.single.trigger('session', {
      'id': 'cs1',
      'status': 'live',
      'ticket_id': 't1',
      'messages': <Object?>[],
    });
    await pumpEventQueue();
    expect(client.conversation.value.status, 'live');

    await client.startNew();
    expect(client.conversation.value.status, 'none');
    expect(sockets, hasLength(2));
    client.dispose();
  });

  test(
    'a chat that ended helped or idle starts afresh; a closed ticket waits',
    () async {
      final (:client, api: _, :sockets, identities: _) = arrange();
      await client.start();
      sockets.single.trigger('ended', {'reason': 'ticket_closed'});
      await pumpEventQueue();
      expect(sockets, hasLength(1));
      sockets.single.trigger('ended', {'reason': 'helped'});
      await pumpEventQueue();
      expect(sockets, hasLength(2));
      sockets.last.trigger('ended', {'reason': 'idle'});
      await pumpEventQueue();
      expect(sockets, hasLength(3));
      client.dispose();
    },
  );

  test('an answers-only brand opens no socket and reads no tickets', () async {
    final (:client, :api, :sockets, identities: _) = arrange();
    api.supportMode = 'assistant_only';
    await client.start();
    await pumpEventQueue();
    expect(sockets, isEmpty);
    expect(api.ticketReads, 0);
    client.dispose();
  });

  test('unread follows refreshTickets and markSeen', () async {
    final (:client, :api, sockets: _, identities: _) = arrange();
    api.tickets = [
      ticketJson('t1', updated: '2026-11-05T10:00:00.000Z'),
      ticketJson('t2'),
    ];
    await client.refreshTickets();
    expect(client.tickets.value.map((ticket) => ticket.id), ['t1', 't2']);
    expect(client.unread.value, 1);

    await client.markSeen(client.tickets.value.first);
    expect(client.unread.value, 0);

    api.tickets = [
      ticketJson('t1', updated: '2026-11-06T08:00:00.000Z'),
      ticketJson('t2'),
    ];
    await client.refreshTickets();
    expect(client.unread.value, 1);
    client.dispose();
  });

  test('opening a merged ticket follows it, and marks both seen', () async {
    final (:client, :api, sockets: _, identities: _) = arrange();
    api.ticketsById = {
      't1': ticketJson(
        't1',
        updated: '2026-11-04T10:00:00.000Z',
        mergedInto: 't2',
      ),
      't2': ticketJson('t2', updated: '2026-11-05T10:00:00.000Z'),
    };
    final ticket = await client.openTicket('t1');
    expect(ticket.id, 't2');
    final stored = await SharedPreferencesAsync().getString(
      'davodesk.seen.ch_1.example-ada',
    );
    expect(jsonDecode(stored!), {
      't1': '2026-11-05T10:00:00.000Z',
      't2': '2026-11-05T10:00:00.000Z',
    });
    client.dispose();
  });

  test('a malformed identity token keys markers under unknown', () async {
    final (:client, :api, sockets: _, identities: _) = arrange(
      token: 'not-a-jwt',
    );
    api.ticketsById = {'t1': ticketJson('t1')};
    await client.openTicket('t1');
    expect(
      await SharedPreferencesAsync().getString('davodesk.seen.ch_1.unknown'),
      contains('t1'),
    );
    client.dispose();
  });

  test('raiseTicket puts the extra field on the first line', () async {
    final (:client, :api, sockets: _, identities: _) = arrange();
    await client.raiseTicket(
      subject: 'Card declined',
      message: 'My card…',
      extraLabel: 'Order ID',
      extraValue: ' #VP-8291 ',
    );
    expect(api.raised.last.body, {
      'subject': 'Card declined',
      'message': 'Order ID: #VP-8291\n\nMy card…',
    });

    await client.raiseTicket(
      subject: 'Again',
      message: 'Hello',
      extraLabel: 'Order ID',
      extraValue: '  ',
    );
    expect(api.raised.last.body['message'], 'Hello');

    final keys = [for (final each in api.raised) each.key];
    expect(keys, everyElement(matches(uuidV4)));
    expect(keys.toSet(), hasLength(2));
    client.dispose();
  });

  test('retries a raise lost in transit with the same key', () {
    fakeAsync((async) {
      final (:client, :api, sockets: _, identities: _) = arrange();
      api.dropNextRaise = true;
      RaisedTicket? raised;
      client
          .raiseTicket(subject: 'Card declined', message: 'My card…')
          .then((value) => raised = value);
      async.elapse(const Duration(seconds: 2));
      expect(raised?.ticket.id, 't9');
      expect(api.raised, hasLength(2));
      expect(api.raised.first.key, api.raised.last.key);
      client.dispose();
    });
  });

  test('a 401 opens a fresh session and tries once more', () async {
    final (:client, :api, sockets: _, identities: _) = arrange();
    api
      ..tickets = [ticketJson('t1')]
      ..refuseNextTickets = 401;
    await client.refreshTickets();
    expect(api.opens, 2);
    expect(api.ticketReads, 2);
    expect(client.tickets.value, hasLength(1));
    client.dispose();
  });

  test(
    'the app coming back opens a fresh session and reads the tickets again',
    () async {
      final (:client, :api, sockets: _, :identities) = arrange();
      await client.refreshTickets();
      final binding = TestWidgetsFlutterBinding.instance;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      expect(identities(), 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(identities(), 2);
      expect(api.ticketReads, 2);
      client.dispose();
    },
  );

  test(
    'logout ends the session, forgets the markers, and asks again next time',
    () async {
      final (:client, :api, sockets: _, :identities) = arrange();
      api
        ..tickets = [ticketJson('t1', updated: '2026-11-05T10:00:00.000Z')]
        ..ticketsById = {
          't1': ticketJson('t1', updated: '2026-11-05T10:00:00.000Z'),
        };
      await client.refreshTickets();
      await client.openTicket('t1');

      await client.logout();
      expect(api.loggedOut, isTrue);
      expect(
        await SharedPreferencesAsync().getString(
          'davodesk.seen.ch_1.example-ada',
        ),
        isNull,
      );
      expect(client.tickets.value, isEmpty);
      expect(client.unread.value, 0);
      expect(client.customerName, isNull);

      await client.refreshTickets();
      expect(identities(), 2);
      client.dispose();
    },
  );
}
