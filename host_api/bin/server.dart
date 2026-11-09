import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

/// The example app's pretend backend: the company server a real app would have. It will sign
/// DavoDesk identity tokens for the example app's pretend customers, holding the signing
/// secret so the app never does.
final _router = Router()..get('/health', _health);

Response _health(Request request) => Response.ok(
  jsonEncode({'ok': true}),
  headers: {'content-type': 'application/json'},
);

void main(List<String> args) async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_router.call);
  final port = int.parse(Platform.environment['PORT'] ?? '8787');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Host API listening on port ${server.port}');
}
