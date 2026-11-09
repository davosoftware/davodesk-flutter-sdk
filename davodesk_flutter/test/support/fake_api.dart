/// The DavoDesk API as the SDK's client and screen tests meet it.
library;

import 'dart:convert';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

/// A JSON answer.
http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A ticket as `GET /v1/tickets/me/:id` answers it.
Map<String, Object?> ticketJson(
  String id, {
  String created = '2026-11-01T09:00:00.000Z',
  String? updated,
  String? mergedInto,
  String status = 'open',
  String? subject,
  Map<String, Object?>? lastMessage,
}) => {
  'id': id,
  'subject': subject ?? 'About $id',
  'status': status,
  'created_at': created,
  'updated_at': updated ?? created,
  'merged_into': mergedInto,
  'last_message': lastMessage,
  'messages': <Object?>[],
};

/// The DavoDesk API for one channel, answering as the real one does.
class FakeApi {
  /// The brand's support mode.
  String supportMode = 'ai_triage';

  /// The channel's settings beyond the required ones, such as `appearance`.
  Map<String, Object?> configExtras = {};

  /// The customer's name in the session's answer.
  String? customerName = 'Ada Lovelace';

  /// How many articles the help centre has published.
  int articleTotal = 3;

  /// Session opens so far.
  int opens = 0;

  /// Config reads so far.
  int configReads = 0;

  /// Ticket list reads so far.
  int ticketReads = 0;

  /// Article reads so far.
  int articleReads = 0;

  /// Whether the session was ended.
  bool loggedOut = false;

  /// The status the next ticket list read is refused with.
  int? refuseNextTickets;

  /// Whether the next raise loses its answer in transit.
  bool dropNextRaise = false;

  /// The customer's tickets.
  List<Map<String, Object?>> tickets = [];

  /// The tickets one read returns, by id.
  Map<String, Map<String, Object?>> ticketsById = {};

  /// Every raise: its body and its idempotency key.
  final raised = <({Map<String, Object?> body, String? key})>[];

  /// The client the SDK talks through.
  late final http.Client httpClient = MockClient(_answer);

  Future<http.Response> _answer(http.Request request) async {
    final path = request.url.path;
    switch ((request.method, path)) {
      case ('GET', '/v1/channels/ch_1/config'):
        configReads++;
        return json({
          'channel_id': 'ch_1',
          'type': 'app',
          'brand_name': 'Davopay',
          'support_mode': supportMode,
          ...configExtras,
        });
      case ('POST', '/v1/end-user-sessions'):
        opens++;
        return json({
          'session_token': 's$opens',
          'token_type': 'Bearer',
          'expires_in': 1800,
          'brand_id': 'app_1',
          'end_user': {'kind': 'identified', 'name': customerName},
        });
      case ('POST', '/v1/end-user-sessions/logout'):
        loggedOut = true;
        return json({'ended': true});
      case ('GET', '/v1/tickets/me'):
        ticketReads++;
        if (refuseNextTickets case final status?) {
          refuseNextTickets = null;
          return json({'code': 'UNAUTHORIZED', 'message': 'No'}, status);
        }
        return json({'tickets': tickets});
      case ('GET', final p) when p.startsWith('/v1/tickets/me/'):
        final ticket = ticketsById[p.split('/').last];
        return ticket == null
            ? json({'message': 'Not found'}, 404)
            : json(ticket);
      case ('POST', '/v1/tickets/me'):
        raised.add((
          body: jsonDecode(request.body) as Map<String, Object?>,
          key: request.headers['Idempotency-Key'],
        ));
        if (dropNextRaise) {
          dropNextRaise = false;
          throw http.ClientException('Connection closed before the answer');
        }
        return json({'resumed': false, 'ticket': ticketJson('t9')});
      case ('GET', '/v1/kb/public/app_1'):
        articleReads++;
        return json({'total': articleTotal, 'articles': <Object?>[]});
    }
    return json({'message': 'No route'}, 404);
  }
}

/// A client over a [FakeApi] and fake sockets; `token: 'ada'` signs Ada in, any other
/// value is passed as the identity token itself.
({
  DavoDeskClient client,
  FakeApi api,
  List<FakeSocket> sockets,
  int Function() identities,
})
arrange({String token = 'ada', FakeApi? api}) {
  final fake = api ?? FakeApi();
  final sockets = <FakeSocket>[];
  var identities = 0;
  final client = DavoDeskClient(
    channelId: 'ch_1',
    identityToken: () async {
      identities++;
      return token == 'ada' ? identity('example-ada') : token;
    },
    apiUrl: Uri.parse('https://api.test'),
    httpClient: fake.httpClient,
    socketFactory: (url, token) {
      final socket = FakeSocket(url, token);
      sockets.add(socket);
      return socket;
    },
  );
  return (
    client: client,
    api: fake,
    sockets: sockets,
    identities: () => identities,
  );
}
