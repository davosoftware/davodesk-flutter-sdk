import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:host_api/identity.dart';
import 'package:test/test.dart';

Object? _decode(String part) =>
    jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))));

void main() {
  test('signs HS256 with the key id, expiring in five minutes', () {
    final now = DateTime.utc(2026, 11, 9, 12);
    final token = signIdentity(
      keyId: 'sk_1',
      secret: 'shh',
      claims: {'sub': 'example-ada', 'name': 'Ada Lovelace'},
      now: now,
    );

    final [head, body, signature] = token.split('.');
    expect(_decode(head), {'alg': 'HS256', 'typ': 'JWT', 'kid': 'sk_1'});
    expect(_decode(body), {
      'sub': 'example-ada',
      'name': 'Ada Lovelace',
      'exp': now.millisecondsSinceEpoch ~/ 1000 + 300,
    });
    final expected = base64Url
        .encode(
          Hmac(
            sha256,
            utf8.encode('shh'),
          ).convert(utf8.encode('$head.$body')).bytes,
        )
        .replaceAll('=', '');
    expect(signature, expected);
    expect(token, isNot(contains('=')));
  });
}
