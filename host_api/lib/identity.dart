import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Signs a DavoDesk identity token: an HS256 JWT whose header names the signing key, and
/// whose `exp` is [ttl] from [now].
///
/// This is what a company's backend does (the integration guide, §2), so the signing
/// secret never reaches the app.
String signIdentity({
  required String keyId,
  required String secret,
  required Map<String, Object?> claims,
  Duration ttl = const Duration(minutes: 5),
  DateTime? now,
}) {
  final issuedAt = now ?? DateTime.now();
  final head = _encode({'alg': 'HS256', 'typ': 'JWT', 'kid': keyId});
  final body = _encode({
    ...claims,
    'exp': issuedAt.add(ttl).millisecondsSinceEpoch ~/ 1000,
  });
  final signature = Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode('$head.$body'));
  return '$head.$body.${_unpadded(base64Url.encode(signature.bytes))}';
}

String _encode(Map<String, Object?> json) =>
    _unpadded(base64Url.encode(utf8.encode(jsonEncode(json))));

String _unpadded(String base64) => base64.replaceAll('=', '');
