import 'dart:io';

import 'package:host_api/app.dart';
import 'package:host_api/config.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

/// The example app's pretend company backend: it signs DavoDesk identity tokens for the
/// app's pretend customers, holding the signing secret so the app never does.
///
/// Settings come from `.env` beside this folder's `pubspec.yaml`, then the environment.
Future<void> main(List<String> args) async {
  final config = HostConfig.fromEnv({
    ...readDotEnv('.env'),
    ...Platform.environment,
  });
  // logRequests prints the method, path and status: never a header or a token.
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildHandler(config));
  final server = await serve(handler, InternetAddress.anyIPv4, config.port);
  stdout.writeln('Host API listening on port ${server.port}');
}
