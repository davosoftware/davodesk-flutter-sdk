import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'identity.dart';

/// A pretend customer of the example app.
class const Customer(final String sub, final String name, final String email);

/// The example app's two pretend customers, as in the web playground.
const customers = {
  'ada': Customer('example-ada', 'Ada Lovelace', 'ada@example.test'),
  'ben': Customer('example-ben', 'Ben Okafor', 'ben@example.test'),
};

/// The host API's routes: health, the app's settings, pretend sign-in, and identity
/// tokens for signed-in customers.
///
/// [now] and [newToken] are for tests.
Handler buildHandler(
  HostConfig config, {
  DateTime Function()? now,
  String Function()? newToken,
}) {
  final signedIn = <String, Customer>{};
  final random = Random.secure();
  String token() =>
      newToken?.call() ??
      List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  final router = Router()
    ..get('/health', (Request _) => _json(200, {'ok': true}))
    ..get(
      '/app-config',
      (Request _) => _json(200, {
        'api_url': config.apiUrl,
        'channel_id': config.channelId,
      }),
    )
    ..post('/login', (Request request) async {
      final body = await _readJson(request);
      final customer = customers[body['customer']];
      if (customer == null) return _json(400, {'error': 'unknown_customer'});
      final demo = 'demo-${token()}';
      signedIn[demo] = customer;
      return _json(200, {'token': demo, 'name': customer.name});
    })
    ..get('/support/identity', (Request request) {
      final header = request.headers['authorization'] ?? '';
      final customer = header.startsWith('Bearer ')
          ? signedIn[header.substring(7)]
          : null;
      if (customer == null) return _json(401, {'error': 'unknown_token'});
      return _json(200, {
        'identity_token': signIdentity(
          keyId: config.signingKeyId,
          secret: config.signingSecret,
          claims: {
            'sub': customer.sub,
            'name': customer.name,
            'email': customer.email,
            'email_verified': true,
          },
          now: now?.call(),
        ),
      });
    });
  return router.call;
}

Response _json(int status, Map<String, Object?> body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

Future<Map<String, Object?>> _readJson(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map<String, Object?> ? decoded : {};
  } on FormatException {
    return {};
  }
}
