import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  const port = '8788';
  const host = 'http://127.0.0.1:$port';
  late Process server;

  setUp(() async {
    server = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      // The server refuses to start without its settings; these are test values.
      environment: {
        'PORT': port,
        'DAVODESK_API_URL': 'http://127.0.0.1:3100',
        'DAVODESK_CHANNEL_ID': 'ch_test',
        'DAVODESK_SIGNING_KEY_ID': 'sk_test',
        'DAVODESK_SIGNING_SECRET': 'test-secret',
      },
    );
    // The server prints once it listens.
    await server.stdout.first;
  });

  tearDown(() => server.kill());

  test('answers its health check', () async {
    final response = await get(Uri.parse('$host/health'));
    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'ok': true});
  });

  test('answers 404 for anything else', () async {
    final response = await get(Uri.parse('$host/nothing'));
    expect(response.statusCode, 404);
  });
}
