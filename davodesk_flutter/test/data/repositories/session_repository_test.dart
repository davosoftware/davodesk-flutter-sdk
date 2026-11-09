import 'dart:async';
import 'dart:convert';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An identity token whose payload names [sub]; its signature doesn't matter here.
String identity(String sub) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub})}.sig';
}

http.Response opened({int expiresIn = 1800}) => http.Response(
  jsonEncode({
    'session_token': 's1',
    'token_type': 'Bearer',
    'expires_in': expiresIn,
    'brand_id': 'app_1',
    'end_user': {'kind': 'identified', 'name': 'Chukwu Obi'},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

/// An opened session whose token is [token].
http.Response tokenResponse(String token) => http.Response(
  jsonEncode({'session_token': token, 'expires_in': 1800, 'brand_id': 'app_1'}),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response refused(int status, String code, {String? retryAfter}) =>
    http.Response(
      jsonEncode({'code': code, 'message': code}),
      status,
      headers: {'content-type': 'application/json', 'retry-after': ?retryAfter},
    );

/// A session over a fake API: [answer] replies to each session open, in order.
({DavoDeskSession session, List<String> calls, int Function() identities})
build({
  List<http.Response> Function()? answers,
  Future<String?> Function()? identityToken,
}) {
  final calls = <String>[];
  var identityCalls = 0;
  final replies = answers?.call() ?? [opened(), opened(), opened()];
  final client = MockClient((request) async {
    calls.add('${request.method} ${request.url.path}');
    if (request.url.path.endsWith('/logout')) {
      return http.Response('{"ended":true}', 200);
    }
    return replies.isEmpty ? opened() : replies.removeAt(0);
  });
  final session = DavoDeskSession(
    api: DavoDeskApi(baseUrl: Uri.parse('https://api.test'), client: client),
    channelId: 'ch_1',
    identityToken:
        identityToken ??
        () async {
          identityCalls++;
          return identity('example-ada');
        },
    random: () => 0.5,
  );
  return (session: session, calls: calls, identities: () => identityCalls);
}

int opens(List<String> calls) =>
    calls.where((call) => call == 'POST /v1/end-user-sessions').length;

void main() {
  test('opens once for callers at the same time', () {
    fakeAsync((async) {
      final (:session, :calls, :identities) = build();
      final results = <SessionState>[];
      session.ensure().then(results.add);
      session.ensure().then(results.add);
      async.flushMicrotasks();

      expect(identities(), 1);
      expect(opens(calls), 1);
      expect(results, hasLength(2));
      expect(results.every((state) => state is SessionReady), isTrue);
      expect(session.subject, 'example-ada');
      session.dispose();
    });
  });

  test('renews a minute before it runs out', () {
    fakeAsync((async) {
      final (:session, :calls, identities: _) = build();
      session.ensure();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1739));
      expect(opens(calls), 1);
      async.elapse(const Duration(seconds: 1));
      expect(opens(calls), 2);
      session.dispose();
    });
  });

  test('retries with backoff when the identity function fails', () {
    fakeAsync((async) {
      var tries = 0;
      final (:session, :calls, identities: _) = build(
        identityToken: () async {
          tries++;
          return null;
        },
      );
      session.ensure();
      async.flushMicrotasks();
      expect(
        session.state,
        isA<SessionUnavailable>().having((s) => s.code, 'code', 'TOKEN_FAILED'),
      );
      expect(opens(calls), 0);

      // random 0.5: 1000 × 2^0 × 0.75, then 1000 × 2^1 × 0.75.
      async.elapse(const Duration(milliseconds: 749));
      expect(tries, 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(tries, 2);
      async.elapse(const Duration(milliseconds: 1500));
      expect(tries, 3);
      session.dispose();
    });
  });

  test('waits for Retry-After on 429', () {
    fakeAsync((async) {
      final (:session, :calls, identities: _) = build(
        answers: () => [
          refused(429, 'RATE_LIMITED', retryAfter: '7'),
          opened(),
        ],
      );
      session.ensure();
      async.flushMicrotasks();
      expect(
        session.state,
        isA<SessionLimited>().having((s) => s.retryAfter, 'retryAfter', 7),
      );
      async.elapse(const Duration(milliseconds: 6999));
      expect(opens(calls), 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(opens(calls), 2);
      expect(session.state, isA<SessionReady>());
      session.dispose();
    });
  });

  test('INVALID_IDENTITY_TOKEN is TOKEN_FAILED; a 401 for the channel is CHANNEL_UNAVAILABLE', () {
    fakeAsync((async) {
      final first = build(
        answers: () => [refused(401, 'INVALID_IDENTITY_TOKEN')],
      );
      first.session.ensure();
      async.flushMicrotasks();
      expect(
        first.session.state,
        isA<SessionUnavailable>().having((s) => s.code, 'code', 'TOKEN_FAILED'),
      );
      first.session.dispose();

      final second = build(answers: () => [refused(401, 'UNAUTHORIZED')]);
      second.session.ensure();
      async.flushMicrotasks();
      expect(
        second.session.state,
        isA<SessionUnavailable>().having(
          (s) => s.code,
          'code',
          'CHANNEL_UNAVAILABLE',
        ),
      );
      second.session.dispose();
    });
  });

  test('ensure waits for a pending retry instead of opening at once', () {
    fakeAsync((async) {
      final (:session, :calls, identities: _) = build(
        answers: () => [refused(503, 'UNAVAILABLE'), opened()],
      );
      session.ensure();
      async.flushMicrotasks();
      session.ensure();
      async.flushMicrotasks();
      expect(opens(calls), 1);
      session.dispose();
    });
  });

  test('logout calls the API, stops renewing and goes idle', () {
    fakeAsync((async) {
      final (:session, :calls, identities: _) = build();
      session.ensure();
      async.flushMicrotasks();
      session.logout();
      async.flushMicrotasks();
      expect(calls, contains('POST /v1/end-user-sessions/logout'));
      expect(session.state, isA<SessionIdle>());
      expect(session.subject, isNull);
      async.elapse(const Duration(hours: 1));
      expect(opens(calls), 1);
      session.dispose();
    });
  });

  test('an identity function that throws before returning is TOKEN_FAILED', () {
    fakeAsync((async) {
      final (:session, calls: _, identities: _) = build(
        identityToken: () => throw StateError('No backend'),
      );
      session.ensure();
      async.flushMicrotasks();
      expect(
        session.state,
        isA<SessionUnavailable>().having((s) => s.code, 'code', 'TOKEN_FAILED'),
      );
      session.dispose();
    });
  });

  test('a logout while the identity token is on its way opens nothing', () {
    fakeAsync((async) {
      final gate = Completer<String?>();
      final (:session, :calls, identities: _) = build(
        identityToken: () => gate.future,
      );
      session.ensure();
      async.flushMicrotasks();
      session.logout();
      async.flushMicrotasks();
      gate.complete(identity('example-ada'));
      async.elapse(const Duration(hours: 1));
      expect(session.state, isA<SessionIdle>());
      expect(session.subject, isNull);
      expect(opens(calls), 0);
      session.dispose();
    });
  });

  test('a session that opens after logout is ended, and the next customer gets their own', () {
    fakeAsync((async) {
      final answers = [Completer<http.Response>(), Completer<http.Response>()];
      final calls = <String>[];
      var opened = 0;
      final client = MockClient((request) {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/logout')) {
          return Future.value(
            http.Response('{"ended":true}', 200, request: request),
          );
        }
        return answers[opened++].future;
      });
      var who = 'example-ada';
      final session = DavoDeskSession(
        api: DavoDeskApi(
          baseUrl: Uri.parse('https://api.test'),
          client: client,
        ),
        channelId: 'ch_1',
        identityToken: () async => identity(who),
        random: () => 0.5,
      );
      session.ensure();
      async.flushMicrotasks();
      session.logout();
      who = 'example-ben';
      SessionState? next;
      session.ensure().then((state) => next = state);
      async.flushMicrotasks();

      answers[0].complete(tokenResponse('s-ada'));
      answers[1].complete(tokenResponse('s-ben'));
      async.flushMicrotasks();
      expect(
        next,
        isA<SessionReady>().having((s) => s.token, 'token', 's-ben'),
      );
      expect(session.subject, 'example-ben');
      expect(calls, contains('POST /v1/end-user-sessions/logout'));
      session.dispose();
    });
  });

  test('backoff caps at five minutes', () {
    expect(backoff(0, 0.5), const Duration(milliseconds: 750));
    expect(backoff(20, 1), const Duration(minutes: 5));
  });
}
