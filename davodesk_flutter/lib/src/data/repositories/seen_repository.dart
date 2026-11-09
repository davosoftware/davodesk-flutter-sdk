import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';

final _log = Logger('DavoDesk');

/// Whether a ticket changed since the customer last looked at it, or, never opened, since
/// it was raised: a request they just made isn't news. A ticket updated before it was
/// raised (the server's clocks apart) isn't either.
bool isUnread(TicketSummary t, Map<String, String> seen) {
  final updated = t.updatedAt;
  final since = DateTime.tryParse(seen[t.id] ?? '') ?? t.createdAt;
  return updated != null && since != null && updated.isAfter(since);
}

/// How many of [tickets] changed since the customer last looked. The API keeps no unread
/// counter; this is the SDK's own reckoning, as the web widget's is.
int unreadCount(List<TicketSummary> tickets, Map<String, String> seen) =>
    tickets.where((ticket) => isUnread(ticket, seen)).length;

/// When the customer last looked at each ticket, kept on the device per channel and
/// customer: the only thing the SDK stores.
///
/// When the device's storage can't be used, it keeps counting in memory.
class SeenStore {
  SharedPreferencesAsync? _preferences;
  String? _key;
  Future<void>? _loading;
  Map<String, String> _markers = const {};

  /// The markers loaded: ticket id to the time the customer last saw it.
  Map<String, String> get markers => _markers;

  /// Loads the markers of `subject` on `channelId`; a customer whose identity token
  /// names no subject is `unknown`. Callers at the same time share one read.
  Future<void> load(String channelId, String? subject) {
    final who = subject == null || subject.isEmpty ? 'unknown' : subject;
    final key = 'davodesk.seen.$channelId.$who';
    if (key == _key) return _loading ?? Future.value();
    _key = key;
    _markers = const {};
    return _loading = _read(key);
  }

  Future<void> _read(String key) async {
    final stored = await _guard(() async => _store()?.getString(key));
    if (stored == null || key != _key) return;
    _markers = {
      if (_decode(stored) case final Map<String, Object?> map)
        for (final MapEntry(:key, :value) in map.entries)
          if (value is String) key: value,
      ..._markers,
    };
  }

  /// Notes that the customer saw `ticketId` as it stood at `at`; it never moves back.
  Future<void> mark(String ticketId, DateTime at) async {
    final seen = DateTime.tryParse(_markers[ticketId] ?? '');
    if (seen != null && !at.isAfter(seen)) return;
    _markers = {..._markers, ticketId: at.toUtc().toIso8601String()};
    if (_key case final key?) {
      await _guard(() async => _store()?.setString(key, jsonEncode(_markers)));
    }
  }

  /// Forgets the loaded customer's markers, on the device too: on logout.
  Future<void> clear() async {
    final key = _key;
    _key = null;
    _loading = null;
    _markers = const {};
    if (key != null) await _guard(() async => _store()?.remove(key));
  }

  SharedPreferencesAsync? _store() => _preferences ??= SharedPreferencesAsync();

  static Future<T?> _guard<T>(Future<T?> Function() use) async {
    try {
      return await use();
    } on Object catch (error) {
      _log.fine('The unread markers could not be stored: $error');
      return null;
    }
  }

  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
