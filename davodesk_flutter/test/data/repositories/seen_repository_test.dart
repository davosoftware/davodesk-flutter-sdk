import 'dart:async';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/data/repositories/seen_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Device storage whose reads wait for [gate].
final class GatedPreferences extends InMemorySharedPreferencesAsync {
  GatedPreferences(super.data) : super.withData();

  final gate = Completer<void>();

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    await gate.future;
    return super.getString(key, options);
  }
}

TicketSummary ticket(String id, String created, String updated) =>
    TicketSummary(
      id: id,
      subject: id,
      status: 'pending',
      createdAt: DateTime.parse(created),
      updatedAt: DateTime.parse(updated),
    );

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('a ticket changed since it was seen is unread; one never opened counts from '
      'when it was raised; clock skew is not unread', () {
    const seen = {
      'a': '2026-11-05T09:00:00.000Z',
      'b': '2026-11-05T12:00:00.000Z',
    };
    final tickets = [
      ticket('a', '2026-11-01T09:00:00Z', '2026-11-05T10:00:00Z'),
      ticket('b', '2026-11-01T09:00:00Z', '2026-11-05T10:00:00Z'),
      ticket('new', '2026-11-05T10:00:00Z', '2026-11-05T10:00:00Z'),
      ticket('old', '2026-11-01T09:00:00Z', '2026-11-05T10:00:00Z'),
      ticket('skew', '2026-11-05T10:00:01Z', '2026-11-05T10:00:00Z'),
    ];
    expect(
      [for (final each in tickets) isUnread(each, seen)],
      [true, false, false, true, false],
    );
    expect(unreadCount(tickets, seen), 2);
    expect(
      isUnread(
        const TicketSummary(id: 'x', subject: 'x', status: 'open'),
        seen,
      ),
      isFalse,
    );
  });

  test(
    'keeps markers per channel and customer, and clears them on logout',
    () async {
      final store = SeenStore();
      await store.load('ch_1', 'example-ada');
      await store.mark('t1', DateTime.utc(2026, 11, 5, 10));
      await store.mark('t1', DateTime.utc(2026, 11, 5, 9));
      expect(store.markers, {'t1': '2026-11-05T10:00:00.000Z'});

      final other = SeenStore();
      await other.load('ch_1', 'example-ben');
      expect(other.markers, isEmpty);
      await other.load('ch_2', 'example-ada');
      expect(other.markers, isEmpty);
      await other.load('ch_1', 'example-ada');
      expect(other.markers, {'t1': '2026-11-05T10:00:00.000Z'});

      await store.clear();
      expect(store.markers, isEmpty);
      final after = SeenStore();
      await after.load('ch_1', 'example-ada');
      expect(after.markers, isEmpty);
    },
  );

  test(
    'a customer without a readable subject keys markers under unknown',
    () async {
      final store = SeenStore();
      await store.load('ch_1', null);
      await store.mark('t1', DateTime.utc(2026, 11, 5, 10));
      expect(
        await SharedPreferencesAsync().getString('davodesk.seen.ch_1.unknown'),
        contains('t1'),
      );
    },
  );

  test(
    'a second load waits for the first, so a mark keeps the stored markers',
    () async {
      final preferences = GatedPreferences({
        'davodesk.seen.ch_1.example-ada': '{"t0":"2026-11-01T09:00:00.000Z"}',
      });
      SharedPreferencesAsyncPlatform.instance = preferences;
      final store = SeenStore();
      final first = store.load('ch_1', 'example-ada');
      var secondDone = false;
      final second = store
          .load('ch_1', 'example-ada')
          .then((_) => secondDone = true);
      await pumpEventQueue();
      expect(secondDone, isFalse);

      preferences.gate.complete();
      await second;
      await store.mark('t1', DateTime.utc(2026, 11, 5, 10));
      await first;
      const both = {
        't0': '2026-11-01T09:00:00.000Z',
        't1': '2026-11-05T10:00:00.000Z',
      };
      expect(store.markers, both);
      final again = SeenStore();
      await again.load('ch_1', 'example-ada');
      expect(again.markers, both);
    },
  );

  test(
    'keeps counting in memory when the device storage is unavailable',
    () async {
      SharedPreferencesAsyncPlatform.instance = null;
      final store = SeenStore();
      await store.load('ch_1', 'example-ada');
      await store.mark('t1', DateTime.utc(2026, 11, 5, 10));
      expect(store.markers, {'t1': '2026-11-05T10:00:00.000Z'});
      await store.clear();
      expect(store.markers, isEmpty);
    },
  );
}
