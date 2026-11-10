import 'dart:convert';

import 'package:davodesk_example/main.dart';
import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

String identity(String sub) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub})}.sig';
}

/// The example's host API and the DavoDesk API, answering as the real ones do.
({http.Client client, List<String> calls}) servers() {
  final calls = <String>[];
  final client = MockClient((request) async {
    calls.add('${request.method} ${request.url.path}');
    return switch ((request.method, request.url.path)) {
      ('POST', '/login') => json({'token': 'demo-1', 'name': 'Ada Lovelace'}),
      ('GET', '/app-config') => json({
        'api_url': 'https://api.test',
        'channel_id': 'ch_1',
      }),
      ('GET', '/support/identity') => json({
        'identity_token': identity('example-ada'),
      }),
      ('GET', '/v1/channels/ch_1/config') => json({
        'channel_id': 'ch_1',
        'brand_name': 'Acme',
        'support_mode': 'ai_triage',
      }),
      ('POST', '/v1/end-user-sessions') => json({
        'session_token': 's1',
        'expires_in': 1800,
        'brand_id': 'app_1',
        'end_user': {'name': 'Ada Lovelace'},
      }),
      ('GET', '/v1/tickets/me') => json({'tickets': <Object?>[]}),
      _ => json({'ended': true}),
    };
  });
  return (client: client, calls: calls);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('signing in as Ada shows Acme with Help; signing out returns', (
    tester,
  ) async {
    final (:client, :calls) = servers();
    await tester.pumpWidget(
      AcmeApp(
        httpClient: client,
        startSupport:
            ({required channelId, required apiUrl, required identityToken}) =>
                DavoDesk.initializeWith(
                  DavoDeskClient(
                    channelId: channelId,
                    identityToken: identityToken,
                    apiUrl: Uri.parse(apiUrl),
                    httpClient: client,
                  ),
                ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in as'), findsOneWidget);

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    expect(find.text('Hi Ada'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Ask about my order'), findsOneWidget);
    expect(find.text('Send us a message'), findsOneWidget);
    expect(calls, contains('GET /support/identity'));

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in as'), findsOneWidget);
    expect(calls, contains('POST /v1/end-user-sessions/logout'));

    await tester.pumpWidget(const SizedBox());
    await DavoDesk.reset();
  });
}
