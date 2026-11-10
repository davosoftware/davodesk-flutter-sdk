import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

/// A refusal from the DavoDesk API: its HTTP [status], its error [code] when it gave one,
/// and how many seconds to wait ([retryAfter]) on a `429`.
class DavoDeskApiError implements Exception {
  /// Creates a refusal.
  const DavoDeskApiError(this.status, this.code, this.retryAfter, this.message);

  /// The HTTP status.
  final int status;

  /// The API's error code, such as `RATE_LIMITED`.
  final String? code;

  /// Seconds to wait before trying again, from `Retry-After`.
  final int? retryAfter;

  /// The API's message.
  final String message;

  @override
  String toString() => 'DavoDeskApiError($status, $code): $message';
}

/// A file to attach to a ticket.
class const UploadFile(
  final String name,
  final List<int> bytes,
  final String contentType,
) {
  /// Creates a [UploadFile].
  this;
}

/// The DavoDesk API's customer-facing calls, exactly as the web widget makes them.
///
/// A native app sends no `Origin`, so every session needs an identity token (the
/// integration guide, §10).
class DavoDeskApi {
  /// Creates the calls against [baseUrl], over [client] when given (tests pass a fake).
  DavoDeskApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// The API's address, such as `https://api.davodesk.com`.
  final Uri baseUrl;
  final http.Client _client;

  /// Reads a channel's public settings.
  Future<ChannelConfig> config(String channelId) async =>
      ChannelConfig.fromJson(
        await _call('GET', '/v1/channels/${_segment(channelId)}/config'),
      );

  /// Opens a customer session on [channelId] with an [identityToken] from the app's backend.
  Future<OpenedSession> openSession({
    required String channelId,
    required String identityToken,
  }) async => OpenedSession.fromJson(
    await _call(
      'POST',
      '/v1/end-user-sessions',
      body: {'channel_id': channelId, 'identity_token': identityToken},
    ),
  );

  /// Ends the session behind [token].
  Future<void> logout(String token) =>
      _call('POST', '/v1/end-user-sessions/logout', token: token);

  /// The customer's tickets.
  Future<List<TicketSummary>> tickets(String token) async {
    final json = await _call('GET', '/v1/tickets/me', token: token);
    return [
      for (final ticket in _list(json['tickets']))
        TicketSummary.fromJson(ticket),
    ];
  }

  /// One of the customer's tickets, with its messages.
  Future<CustomerTicket> ticket(String token, String id) async =>
      CustomerTicket.fromJson(
        await _call('GET', '/v1/tickets/me/${_segment(id)}', token: token),
      );

  /// Rates a ticket `good` or `bad`, with an optional [comment].
  Future<CustomerTicket> rate(
    String token,
    String id, {
    required String rating,
    String? comment,
  }) async => CustomerTicket.fromJson(
    await _call(
      'POST',
      '/v1/tickets/me/${_segment(id)}/satisfaction',
      token: token,
      body: {'rating': rating, 'comment': ?comment},
    ),
  );

  /// Reopens a solved ticket.
  Future<CustomerTicket> reopen(String token, String id) async =>
      CustomerTicket.fromJson(
        await _call(
          'POST',
          '/v1/tickets/me/${_segment(id)}/reopen',
          token: token,
        ),
      );

  /// Raises a ticket, or adds to the open one (then [RaisedTicket.resumed] is true).
  ///
  /// The same [idempotencyKey] on a retry never adds the message twice. [subjectKey]
  /// names one of the brand's request subjects.
  Future<RaisedTicket> raiseTicket(
    String token, {
    required String subject,
    required String message,
    required String idempotencyKey,
    String? subjectKey,
  }) async {
    final json = await _call(
      'POST',
      '/v1/tickets/me',
      token: token,
      body: {
        'subject': subject,
        'message': message,
        'subject_key': ?subjectKey,
      },
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return RaisedTicket(
      json['resumed'] == true,
      CustomerTicket.fromJson(switch (json['ticket']) {
        final Map<String, Object?> ticket => ticket,
        _ => throw const FormatException('A raised ticket without its ticket'),
      }),
    );
  }

  /// Attaches [files] to a ticket.
  Future<void> attach(
    String token,
    String ticketId,
    List<UploadFile> files,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      baseUrl.resolve('/v1/attachments/tickets/${_segment(ticketId)}'),
    )..headers['Authorization'] = 'Bearer $token';
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.name,
          contentType: http.MediaType.parse(file.contentType),
        ),
      );
    }
    _read(await http.Response.fromStream(await _client.send(request)));
  }

  /// Searches the brand's help centre.
  Future<List<ArticleHit>> search(String brandId, String query) async {
    final json = await _call(
      'GET',
      '/v1/kb/public/${_segment(brandId)}/search',
      query: {'q': query},
    );
    return [
      for (final hit in _list(json['articles'])) ArticleHit.fromJson(hit),
    ];
  }

  /// The brand's published articles, all or one collection's.
  Future<ArticlePage> articles(
    String brandId, {
    String? categoryId,
    int? limit,
  }) async {
    final json = await _call(
      'GET',
      '/v1/kb/public/${_segment(brandId)}',
      query: {'category_id': ?categoryId, 'limit': ?limit?.toString()},
    );
    return ArticlePage(
      switch (json['total']) {
        final int total => total,
        _ => 0,
      },
      [
        for (final article in _list(json['articles']))
          PublicArticle.fromJson(article),
      ],
    );
  }

  /// One published article, or null when it no longer exists.
  Future<PublicArticle?> article(String brandId, String id) async {
    try {
      return PublicArticle.fromJson(
        await _call(
          'GET',
          '/v1/kb/public/${_segment(brandId)}/${_segment(id)}',
        ),
      );
    } on DavoDeskApiError catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  /// The brand's help-centre collections.
  Future<List<CategoryNode>> categories(String brandId) async {
    final json = await _call(
      'GET',
      '/v1/kb/public/${_segment(brandId)}/categories',
    );
    return [
      for (final node in _list(json['categories'])) CategoryNode.fromJson(node),
    ];
  }

  /// Says whether an article helped.
  Future<void> vote(String token, String articleId, {required bool helpful}) =>
      _call(
        'PUT',
        '/v1/kb/me/${_segment(articleId)}/feedback',
        token: token,
        body: {'helpful': helpful},
      );

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String> headers = const {},
    Map<String, String> query = const {},
  }) async {
    final request =
        http.Request(
            method,
            baseUrl
                .resolve(path)
                .replace(queryParameters: query.isEmpty ? null : query),
          )
          ..headers.addAll({
            'Authorization': ?(token == null ? null : 'Bearer $token'),
            ...headers,
          });
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return _read(await http.Response.fromStream(await _client.send(request)));
  }

  Map<String, Object?> _read(http.Response response) {
    final decoded = response.body.isEmpty ? null : _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, Object?> ? decoded : const {};
    }
    final map = decoded is Map<String, Object?>
        ? decoded
        : const <String, Object?>{};
    final message = switch (map['message']) {
      final String text => text,
      final List<Object?> texts when texts.isNotEmpty => texts.first.toString(),
      _ => 'The API answered ${response.statusCode}',
    };
    final retry = int.tryParse(response.headers['retry-after'] ?? '');
    throw DavoDeskApiError(
      response.statusCode,
      map['code'] is String ? map['code']! as String : null,
      retry != null && retry > 0 ? retry : null,
      message,
    );
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static List<Map<String, Object?>> _list(Object? value) => value is List
      ? value.whereType<Map<String, Object?>>().toList()
      : const [];

  static String _segment(String value) => Uri.encodeComponent(value);
}
