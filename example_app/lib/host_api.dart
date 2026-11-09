import 'dart:convert';

import 'package:http/http.dart' as http;

/// The example's pretend company backend (`host_api/`): pretend sign-in, the app's
/// DavoDesk settings, and identity tokens for the signed-in customer.
class HostApi {
  /// Creates the calls against [baseUrl].
  HostApi(this.baseUrl, this._client);

  /// Where the host API runs.
  final Uri baseUrl;
  final http.Client _client;

  /// Signs in as a pretend customer (`ada` or `ben`): their demo token and name.
  Future<({String token, String name})> login(String customer) async {
    final json = await _call(
      _client.post(
        baseUrl.resolve('/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'customer': customer}),
      ),
    );
    return (token: json['token']! as String, name: json['name']! as String);
  }

  /// The app's DavoDesk settings.
  Future<({String apiUrl, String channelId})> appConfig() async {
    final json = await _call(_client.get(baseUrl.resolve('/app-config')));
    return (
      apiUrl: json['api_url']! as String,
      channelId: json['channel_id']! as String,
    );
  }

  /// A fresh identity token for the customer signed in with [token]; null when the
  /// host API refuses.
  Future<String?> identityToken(String token) async {
    try {
      final json = await _call(
        _client.get(
          baseUrl.resolve('/support/identity'),
          headers: {'authorization': 'Bearer $token'},
        ),
      );
      return json['identity_token'] as String?;
    } on Object {
      return null;
    }
  }

  Future<Map<String, Object?>> _call(Future<http.Response> request) async {
    final response = await request;
    if (response.statusCode != 200) {
      throw StateError('The host API answered ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, Object?>;
  }
}
