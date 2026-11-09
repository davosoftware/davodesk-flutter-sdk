/// Stand-ins the SDK's tests share.
library;

import 'dart:convert';

import 'package:davodesk_flutter/davodesk_flutter.dart';

/// An identity token whose payload names [sub]; its signature doesn't matter here.
String identity(String sub) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': sub})}.sig';
}

/// A socket.io stand-in: tests play the server with [trigger] and read [sent].
class FakeSocket implements ChatSocket {
  /// Creates the socket the chat asked for at [url] with [token].
  FakeSocket(this.url, String token) : auth = {'token': token};

  /// Where the chat connects.
  final Uri url;

  @override
  Map<String, Object?> auth;

  @override
  bool active = true;

  /// How many times the chat connected it.
  int connects = 0;

  /// How many times the chat disconnected it.
  int disconnects = 0;

  /// Each call as `[event, payload]`.
  final sent = <List<Object?>>[];

  /// What the server answers to an event; `{ok: true}` otherwise.
  final answers = <String, Object?>{};

  final _handlers = <String, List<void Function(Object? data)>>{};

  @override
  void on(String event, void Function(Object? data) handler) =>
      (_handlers[event] ??= []).add(handler);

  @override
  void connect() => connects++;

  @override
  void disconnect() {
    disconnects++;
    active = false;
  }

  @override
  Future<Object?> emitWithAck(String event, Object? payload) async {
    sent.add([event, payload]);
    return answers[event] ?? {'ok': true};
  }

  /// The server sends [event] with [data].
  void trigger(String event, [Object? data]) {
    for (final handler in [...?_handlers[event]]) {
      handler(data);
    }
  }
}
