import 'dart:async';
import 'dart:convert';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A socket.io stand-in: tests play the server with [trigger] and read [sent].
class FakeSocket implements ChatSocket {
  FakeSocket(this.url, String token) : auth = {'token': token};

  final Uri url;

  @override
  Map<String, Object?> auth;

  @override
  bool active = true;

  int connects = 0;
  int disconnects = 0;

  /// Each call as `[event, payload]`.
  final sent = <List<Object?>>[];

  /// What the server answers to an event; `{ok: true}` otherwise.
  final answers = <String, Object?>{};

  final _handlers = <String, List<void Function(Object? data)>>{};

  @override
  void on(String event, void Function(Object? data) handler) =>
      (_handlers[event] ??= []).add(handler);

  @override
  void connect() => connects++;

  @override
  void disconnect() {
    disconnects++;
    active = false;
  }

  @override
  Future<Object?> emitWithAck(String event, Object? payload) async {
    sent.add([event, payload]);
    return answers[event] ?? {'ok': true};
  }

  void trigger(String event, [Object? data]) {
    for (final handler in [...?_handlers[event]]) {
      handler(data);
    }
  }
}

String identity(String sub) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub})}.sig';
}

const snapshot = {
  'id': 'cs1',
  'brand_id': 'app_1',
  'status': 'answers',
  'ticket_id': null,
  'messages': <Object?>[],
};

/// A chat over fake sockets, with a session whose opens hand out s1, s2, … in turn.
({
  DavoDeskChat chat,
  List<FakeSocket> sockets,
  List<ChatEvent> events,
  int Function() opens,
})
arrange({Future<String?> Function()? identityToken}) {
  var opens = 0;
  final client = MockClient((request) async {
    opens++;
    return http.Response(
      jsonEncode({
        'session_token': 's$opens',
        'token_type': 'Bearer',
        'expires_in': 1800,
        'brand_id': 'app_1',
        'end_user': {'kind': 'identified', 'name': 'Ada Lovelace'},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final session = DavoDeskSession(
    api: DavoDeskApi(baseUrl: Uri.parse('https://api.test'), client: client),
    channelId: 'ch_1',
    identityToken: identityToken ?? () async => identity('example-ada'),
    random: () => 0.5,
  );
  final sockets = <FakeSocket>[];
  final chat = DavoDeskChat(
    apiUrl: Uri.parse('https://api.test'),
    session: session,
    socketFactory: (url, token) {
      final socket = FakeSocket(url, token);
      sockets.add(socket);
      return socket;
    },
    random: () => 1,
  );
  final events = <ChatEvent>[];
  chat.events.listen(events.add);
  return (chat: chat, sockets: sockets, events: events, opens: () => opens);
}

Matcher connection(ChatConnection state) =>
    isA<ConnectionEvent>().having((event) => event.state, 'state', state);

void main() {
  test('connects with the session token, and passes on the snapshot', () {
    fakeAsync((async) {
      final (:chat, :sockets, :events, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      final socket = sockets.single;
      expect(socket.url, Uri.parse('https://api.test/chat'));
      expect(socket.auth, {'token': 's1'});
      expect(socket.connects, 1);

      socket.trigger('session', snapshot);
      async.flushMicrotasks();
      expect(events.first, connection(.connecting));
      expect(
        events.whereType<SessionEvent>().single.snapshot.status,
        'answers',
      );
      expect(events.last, connection(.live));
      chat.dispose();
    });
  });

  test('passes on what the server sends', () {
    fakeAsync((async) {
      final (:chat, :sockets, :events, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      sockets.single
        ..trigger('message', {
          'id': 'm1',
          'sender_type': 'bot',
          'content': 'Hello',
        })
        ..trigger('handoff', {
          'ticket_id': 't1',
          'resumed': true,
          'reason': 'customer_requested',
        })
        ..trigger('human_joined', {'display_name': null})
        ..trigger('ended', {'reason': 'ticket_closed'})
        ..trigger('resolved', {'ticket_id': 't1'})
        ..trigger('chat_error', {
          'code': 'RATE_LIMITED',
          'retry_after_seconds': 20,
        });
      async.flushMicrotasks();
      expect(events.skip(1).toList(), [
        isA<MessageEvent>().having(
          (e) => e.message.content,
          'content',
          'Hello',
        ),
        isA<HandoffEvent>()
            .having((e) => e.ticketId, 'ticketId', 't1')
            .having((e) => e.resumed, 'resumed', isTrue)
            .having((e) => e.reason, 'reason', 'customer_requested'),
        isA<HumanJoinedEvent>().having(
          (e) => e.displayName,
          'displayName',
          isNull,
        ),
        isA<EndedEvent>().having((e) => e.reason, 'reason', 'ticket_closed'),
        isA<ResolvedEvent>().having((e) => e.ticketId, 'ticketId', 't1'),
        isA<ChatErrorEvent>()
            .having((e) => e.code, 'code', 'RATE_LIMITED')
            .having((e) => e.retryAfter, 'retryAfter', 20),
      ]);
      chat.dispose();
    });
  });

  test('waits for session before sending', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      ChatAck? ack;
      chat.send('Hi').then((value) => ack = value);
      async.flushMicrotasks();
      expect(sockets.single.sent, isEmpty);
      expect(ack, isNull);

      sockets.single.trigger('session', snapshot);
      async.flushMicrotasks();
      expect(sockets.single.sent, [
        [
          'message',
          {'content': 'Hi'},
        ],
      ]);
      expect(ack?.ok, isTrue);
      chat.dispose();
    });
  });

  test('holds a call made before connecting, and sends it once admitted', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, opens: _) = arrange();
      chat
        ..send('Typed early')
        ..connect();
      async.flushMicrotasks();
      expect(sockets.single.sent, isEmpty);
      sockets.single.trigger('session', snapshot);
      async.flushMicrotasks();
      expect(sockets.single.sent, [
        [
          'message',
          {'content': 'Typed early'},
        ],
      ]);
      chat.dispose();
    });
  });

  test('holds calls again while the server admits it after a cut', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      final socket = sockets.single
        ..trigger('session', snapshot)
        ..trigger('disconnect', 'io server disconnect');
      chat.send('Still there?');
      async.flushMicrotasks();
      expect(socket.sent, isEmpty);
      socket.trigger('session', snapshot);
      async.flushMicrotasks();
      expect(socket.sent, [
        [
          'message',
          {'content': 'Still there?'},
        ],
      ]);
      chat.dispose();
    });
  });

  test('chooses, asks for a person and confirms, returning the answers', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      final socket = sockets.single..trigger('session', snapshot);
      socket.answers['handoff:request'] = {
        'ok': true,
        'handed_off': true,
        'ticket_id': 't9',
      };
      ChatAck? handoff;
      chat.choose('t1');
      chat.requestHandoff().then((value) => handoff = value);
      chat.confirmResolution(solved: true);
      async.flushMicrotasks();
      expect(socket.sent, [
        [
          'option:choose',
          {'key': 't1'},
        ],
        ['handoff:request', <String, Object?>{}],
        [
          'resolution:confirm',
          {'solved': true},
        ],
      ]);
      expect(handoff?.handedOff, isTrue);
      expect(handoff?.ticketId, 't9');
      chat.dispose();
    });
  });

  test('answers ok:false with no connection coming', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      ChatAck? waiting;
      chat.send('Hi').then((value) => waiting = value);
      async.flushMicrotasks();
      chat.disconnect();
      async.flushMicrotasks();
      expect(waiting?.ok, isFalse);

      ChatAck? after;
      chat.send('Hi again').then((value) => after = value);
      async.flushMicrotasks();
      expect(after?.ok, isFalse);
      expect(sockets.single.sent, isEmpty);
      chat.dispose();
    });
  });

  test('a disconnect while the session opens leaves no socket', () {
    fakeAsync((async) {
      final gate = Completer<String?>();
      final (:chat, :sockets, events: _, opens: _) = arrange(
        identityToken: () => gate.future,
      );
      chat.connect();
      async.flushMicrotasks();
      chat.disconnect();
      gate.complete(identity('example-ada'));
      async.flushMicrotasks();
      expect(sockets, isEmpty);
      chat.dispose();
    });
  });

  test('connects as soon as a failed session opens', () {
    fakeAsync((async) {
      var tries = 0;
      final (:chat, :sockets, events: _, :opens) = arrange(
        identityToken: () async =>
            ++tries == 1 ? null : identity('example-ada'),
      );
      chat.connect();
      async.flushMicrotasks();
      expect(sockets, isEmpty);
      // The session's own backoff: 1000 × 2^0 × (0.5 + 0.5 / 2).
      async.elapse(const Duration(milliseconds: 750));
      expect(opens(), 1);
      expect(sockets.single.auth, {'token': 's1'});
      expect(sockets.single.connects, 1);
      chat.dispose();
    });
  });

  test('renews the session on UNAUTHENTICATED once socket.io gave up', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, :opens) = arrange();
      chat.connect();
      async.flushMicrotasks();
      final socket = sockets.single..active = false;
      socket.trigger('connect_error', {'message': 'UNAUTHENTICATED'});
      async.elapse(const Duration(milliseconds: 999));
      expect(opens(), 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(opens(), 2);
      expect(socket.auth, {'token': 's2'});
      expect(socket.connects, 2);
      chat.dispose();
    });
  });

  test('leaves retrying to socket.io while it is still at it', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, :opens) = arrange();
      chat.connect();
      async.flushMicrotasks();
      sockets.single.trigger('connect_error', {'message': 'UNAUTHENTICATED'});
      async.elapse(const Duration(minutes: 10));
      expect(opens(), 1);
      expect(sockets.single.connects, 1);
      chat.dispose();
    });
  });

  test('retries the same token on CONNECTION_FAILED', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, :opens) = arrange();
      chat.connect();
      async.flushMicrotasks();
      final socket = sockets.single..active = false;
      socket.trigger('connect_error', {'message': 'CONNECTION_FAILED'});
      async.elapse(const Duration(seconds: 1));
      expect(opens(), 1);
      expect(socket.auth, {'token': 's1'});
      expect(socket.connects, 2);
      chat.dispose();
    });
  });

  test(
    'renews after a server disconnect, and only reports reconnecting otherwise',
    () {
      fakeAsync((async) {
        final (:chat, :sockets, :events, :opens) = arrange();
        chat.connect();
        async.flushMicrotasks();
        final socket = sockets.single
          ..trigger('session', snapshot)
          ..trigger('disconnect', 'transport close');
        async.flushMicrotasks();
        expect(events.last, connection(.reconnecting));
        async.elapse(const Duration(minutes: 10));
        expect(opens(), 1);
        expect(socket.connects, 1);

        socket.trigger('disconnect', 'io server disconnect');
        async.elapse(const Duration(seconds: 1));
        expect(opens(), 2);
        expect(socket.auth, {'token': 's2'});
        expect(socket.connects, 2);
        chat.dispose();
      });
    },
  );

  test('resets its backoff only once the server admits it', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, opens: _) = arrange();
      chat.connect();
      async.flushMicrotasks();
      final socket = sockets.single;
      void fail() => socket
        ..active = false
        ..trigger('connect_error', {'message': 'CONNECTION_FAILED'});

      fail();
      async.elapse(const Duration(milliseconds: 1000));
      expect(socket.connects, 2);
      fail();
      async.elapse(const Duration(milliseconds: 1999));
      expect(socket.connects, 2);
      async.elapse(const Duration(milliseconds: 1));
      expect(socket.connects, 3);

      socket.trigger('connect');
      fail();
      async.elapse(const Duration(milliseconds: 3999));
      expect(socket.connects, 3);
      async.elapse(const Duration(milliseconds: 1));
      expect(socket.connects, 4);

      socket.trigger('session', snapshot);
      fail();
      async.elapse(const Duration(milliseconds: 1000));
      expect(socket.connects, 5);
      chat.dispose();
    });
  });

  test(
    'starts afresh on restart, holding calls until the new socket is admitted',
    () {
      fakeAsync((async) {
        final (:chat, :sockets, events: _, opens: _) = arrange();
        chat.connect();
        async.flushMicrotasks();
        sockets.single.trigger('session', snapshot);
        chat.restart();
        async.flushMicrotasks();
        expect(sockets.first.disconnects, 1);
        expect(sockets, hasLength(2));

        chat.send('Another question');
        async.flushMicrotasks();
        expect(sockets.last.sent, isEmpty);
        sockets.last.trigger('session', snapshot);
        async.flushMicrotasks();
        expect(sockets.last.sent, [
          [
            'message',
            {'content': 'Another question'},
          ],
        ]);
        chat.dispose();
      });
    },
  );

  test('stops for good when asked to disconnect', () {
    fakeAsync((async) {
      final (:chat, :sockets, events: _, :opens) = arrange();
      chat.connect();
      async.flushMicrotasks();
      chat.disconnect();
      final socket = sockets.single;
      expect(socket.disconnects, 1);
      socket.trigger('disconnect', 'io server disconnect');
      async.elapse(const Duration(minutes: 10));
      expect(opens(), 1);
      expect(socket.connects, 1);
      chat.dispose();
    });
  });
}
