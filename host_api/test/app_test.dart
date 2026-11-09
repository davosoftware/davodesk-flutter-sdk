import 'dart:convert';

import 'package:host_api/app.dart';
import 'package:host_api/config.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const config = HostConfig(
  apiUrl: 'http://10.0.2.2:3100',
  channelId: 'ch_test',
  signingKeyId: 'sk_1',
  signingSecret: 'shh',
  port: 8787,
);

Future<(int, Object?)> call(
  Handler handler,
  String method,
  String path, {
  Object? body,
  String? token,
}) async {
  final response = await handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {'content-type': 'application/json', 'authorization': ?token},
    ),
  );
  final text = await response.readAsString();
  return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
}

Object? payloadOf(String jwt) => jsonDecode(
  utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1]))),
);

void main() {
  late Handler handler;
  setUp(() => handler = buildHandler(config));

  // A record compares its fields with ==, which is identity for a map: so each check
  // takes the record apart.
  test('answers its health check', () async {
    final (status, body) = await call(handler, 'GET', '/health');
    expect(status, 200);
    expect(body, {'ok': true});
  });

  test('gives the app the API address and channel', () async {
    final (status, body) = await call(handler, 'GET', '/app-config');
    expect(status, 200);
    expect(body, {'api_url': 'http://10.0.2.2:3100', 'channel_id': 'ch_test'});
  });

  test(
    'signs in a pretend customer, and refuses one it does not know',
    () async {
      final (status, body) = await call(
        handler,
        'POST',
        '/login',
        body: {'customer': 'ada'},
      );
      expect(status, 200);
      expect(body, {'token': isA<String>(), 'name': 'Ada Lovelace'});
      expect(
        (await call(handler, 'POST', '/login', body: {'customer': 'carol'})).$1,
        400,
      );
    },
  );

  test('signs an identity token for a signed-in customer only', () async {
    final (_, login) = await call(
      handler,
      'POST',
      '/login',
      body: {'customer': 'ada'},
    );
    final token = (login as Map<String, Object?>)['token'] as String;

    final (status, body) = await call(
      handler,
      'GET',
      '/support/identity',
      token: 'Bearer $token',
    );
    expect(status, 200);
    final identity = (body as Map<String, Object?>)['identity_token'] as String;
    expect(payloadOf(identity), containsPair('sub', 'example-ada'));
    expect(payloadOf(identity), containsPair('email_verified', true));

    expect((await call(handler, 'GET', '/support/identity')).$1, 401);
    expect(
      (await call(
        handler,
        'GET',
        '/support/identity',
        token: 'Bearer nope',
      )).$1,
      401,
    );
  });

  test('names the missing settings, and never their values', () {
    expect(
      () => HostConfig.fromEnv({
        'DAVODESK_API_URL': 'http://10.0.2.2:3100',
        'DAVODESK_CHANNEL_ID': 'ch_test',
        'DAVODESK_SIGNING_KEY_ID': 'sk_1',
      }),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('DAVODESK_SIGNING_SECRET'),
            isNot(contains('ch_test')),
          ),
        ),
      ),
    );
  });
}
