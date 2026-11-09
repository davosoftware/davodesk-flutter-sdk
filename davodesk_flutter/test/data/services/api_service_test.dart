import 'dart:convert';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An API over a fake HTTP client that records each request and answers with [reply].
(DavoDeskApi, List<http.Request>) apiWith(
  http.Response Function(http.Request request) reply,
) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return reply(request);
  });
  return (
    DavoDeskApi(baseUrl: Uri.parse('https://api.test'), client: client),
    requests,
  );
}

http.Response json(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

Map<String, Object?> ticketJson({Map<String, Object?> extra = const {}}) => {
  'id': '6a0000000000009bbc55',
  'subject': 'Refund for order #4471',
  'status': 'open',
  'origin': 'chat',
  'satisfaction': null,
  'created_at': '2026-11-09T09:00:00Z',
  'updated_at': '2026-11-09T10:00:00Z',
  'messages': <Object?>[],
  'merged_into': null,
  'resolved_by_ai': false,
  'reopenable': false,
  ...extra,
};

void main() {
  test(
    'opens a session with the channel and identity token, and no Origin',
    () async {
      final (api, requests) = apiWith(
        (_) => json({
          'session_token': 's1',
          'token_type': 'Bearer',
          'expires_in': 1800,
          'brand_id': 'app_1',
          'end_user': {'kind': 'identified', 'name': 'Chukwu Obi'},
        }),
      );

      final opened = await api.openSession(
        channelId: 'ch_1',
        identityToken: 'id.token.sig',
      );

      expect(
        requests.single.url.toString(),
        'https://api.test/v1/end-user-sessions',
      );
      expect(jsonDecode(requests.single.body), {
        'channel_id': 'ch_1',
        'identity_token': 'id.token.sig',
      });
      expect(
        requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('origin')),
      );
      expect(opened.sessionToken, 's1');
      expect(opened.expiresIn, const Duration(minutes: 30));
      expect(opened.customerName, 'Chukwu Obi');
    },
  );

  test('sends the bearer token on the customer’s calls', () async {
    final (api, requests) = apiWith((_) => json({'tickets': <Object?>[]}));
    await api.tickets('s1');
    expect(requests.single.headers['authorization'], 'Bearer s1');
    expect(requests.single.url.path, '/v1/tickets/me');
  });

  test('raises a ticket with an idempotency key, and reads resumed', () async {
    final (api, requests) = apiWith(
      (_) => json({'resumed': true, 'ticket': ticketJson()}),
    );
    final raised = await api.raiseTicket(
      's1',
      subject: 'Card refund',
      message: 'Order ID: #VP-8291\n\nMy card…',
      idempotencyKey: 'key-1',
    );
    expect(requests.single.headers['idempotency-key'], 'key-1');
    expect(jsonDecode(requests.single.body), {
      'subject': 'Card refund',
      'message': 'Order ID: #VP-8291\n\nMy card…',
    });
    expect(raised.resumed, isTrue);
    expect(raised.ticket.subject, 'Refund for order #4471');
  });

  test(
    'turns a refusal into DavoDeskApiError with code and Retry-After',
    () async {
      final (api, _) = apiWith(
        (_) => json(
          {'code': 'RATE_LIMITED', 'message': 'Slow down'},
          status: 429,
          headers: {'retry-after': '7'},
        ),
      );
      expect(
        api.tickets('s1'),
        throwsA(
          isA<DavoDeskApiError>()
              .having((error) => error.status, 'status', 429)
              .having((error) => error.code, 'code', 'RATE_LIMITED')
              .having((error) => error.retryAfter, 'retryAfter', 7),
        ),
      );
    },
  );

  test(
    'reads a config with every new field, and defaults the AI name',
    () async {
      final (api, _) = apiWith(
        (_) => json({
          'channel_id': 'ch_1',
          'type': 'app',
          'brand_name': 'Davopay',
          'support_mode': 'ai_triage',
          'logo_url': null,
          'header_logo_url': 'https://cdn.test/h.webp',
          'tagline': 'Your global money partner',
          'chat_notice': 'We’re busy today.',
          'answers_enabled': true,
          'ai_enabled': true,
          'appearance': null,
        }),
      );
      final config = await api.config('ch_1');
      expect(config.brandName, 'Davopay');
      expect(config.aiAgentName, 'DavoDesk AI');
      expect(config.headerLogoUrl, 'https://cdn.test/h.webp');
      expect(config.tagline, 'Your global money partner');
      expect(config.chatNotice, 'We’re busy today.');
      expect(config.appearance, isNull);
    },
  );

  test('tolerates a ticket message without chat-only fields', () async {
    final (api, _) = apiWith(
      (_) => json(
        ticketJson(
          extra: {
            'messages': [
              {
                'id': 'm1',
                'sender_type': 'staff',
                'content': 'On it',
                'sender_display_name': 'Mara',
                'sent_at': '2026-11-09T10:00:00Z',
              },
            ],
          },
        ),
      ),
    );
    final ticket = await api.ticket('s1', '6a0000000000009bbc55');
    final message = ticket.messages.single;
    expect(message.senderType, SenderType.staff);
    expect(message.options, isEmpty);
    expect(message.botSources, isEmpty);
    expect(message.confirmationRequested, isFalse);
  });
}
