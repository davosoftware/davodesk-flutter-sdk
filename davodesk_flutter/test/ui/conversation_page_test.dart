import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/conversation/conversation_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';
import '../support/pages.dart';

const notice =
    'We’re handling a high volume of requests, so replies may take a bit '
    'longer than usual.';

FakeApi chatApi({bool withNotice = true}) => FakeApi()
  ..customerName = 'Chukwu Obi'
  ..configExtras = {
    'ai_agent_name': 'Callie',
    'tagline': 'Your global money partner',
    'chat_notice': ?(withNotice ? notice : null),
  };

Map<String, Object?> bot(
  String id,
  String content, {
  List<(String, String)> options = const [],
  bool confirm = false,
}) => {
  'id': id,
  'sender_type': 'bot',
  'content': content,
  'options': [
    for (final (key, label) in options) {'key': key, 'label': label},
  ],
  'confirmation_requested': confirm,
};

Map<String, Object?> me(String id, String content) => {
  'id': id,
  'sender_type': 'end_user',
  'content': content,
};

Map<String, Object?> snapshot({
  String status = 'answers',
  String? ticketId,
  List<Map<String, Object?>> messages = const [],
}) => {
  'id': 'cs1',
  'status': status,
  'ticket_id': ticketId,
  'messages': messages,
};

/// The conversation page, its socket admitted with [first].
Future<(PageHarness, FakeSocket)> open(
  WidgetTester tester, {
  FakeApi? api,
  Map<String, Object?>? first,
  double textScale = 1,
  Future<UploadFile?> Function(AttachFrom from)? pickAttachment,
}) async {
  final page = await pumpPage(
    tester,
    ConversationPage.new,
    api: api ?? chatApi(),
    textScale: textScale,
    pickAttachment: pickAttachment,
  );
  final socket = page.sockets.single
    ..trigger('session', first ?? snapshot(messages: [bot('m1', 'Hello')]));
  await tester.pumpAndSettle();
  return (page, socket);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'the header names the AI, then the person who joined with the reference',
    (tester) async {
      final (page, socket) = await open(tester);
      expect(find.text('Callie'), findsOneWidget);
      expect(find.text('The team can also help'), findsOneWidget);
      expect(find.text('Callie · AI Agent'), findsOneWidget);
      expect(find.text('Ask a question…'), findsOneWidget);

      socket
        ..trigger('handoff', {
          'ticket_id': '6a0000000000009bbc55',
          'resumed': false,
          'reason': 'customer_requested',
        })
        ..trigger('human_joined', {'display_name': 'Mara'});
      await tester.pumpAndSettle();
      expect(find.text('Mara'), findsOneWidget);
      expect(find.text('Davopay team · #9BBC55'), findsOneWidget);
      expect(find.text('Mara joined'), findsOneWidget);
      expect(find.text('Write a message…'), findsOneWidget);
      await page.finish(tester);
    },
  );

  testWidgets('a person with no name shows as the brand\'s team', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    socket
      ..trigger('handoff', {
        'ticket_id': '6a0000000000009bbc55',
        'resumed': false,
        'reason': 'customer_requested',
      })
      ..trigger('human_joined', {'display_name': null});
    await tester.pumpAndSettle();
    expect(find.text('Davopay team'), findsOneWidget);
    expect(find.text('Davopay team · #9BBC55'), findsOneWidget);
    expect(find.text('Davopay team joined'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets('the tagline, then the notice when it is set', (tester) async {
    final (page, _) = await open(tester);
    final tagline = tester.getTopLeft(find.text('Your global money partner'));
    expect(tagline.dy, lessThan(tester.getTopLeft(find.text(notice)).dy));
    await page.finish(tester);

    final (quiet, _) = await open(tester, api: chatApi(withNotice: false));
    expect(find.text(notice), findsNothing);
    expect(find.text('Your global money partner'), findsOneWidget);
    await quiet.finish(tester);
  });

  testWidgets(
    'choices are chips; the box waits for them, and comes back after Something Else',
    (tester) async {
      final (page, socket) = await open(
        tester,
        first: snapshot(
          messages: [
            bot(
              'm1',
              'Please choose the option that best matches your request.',
              options: [('t1', 'Virtual Cards'), ('__else', 'Something Else')],
            ),
          ],
        ),
      );
      expect(find.text('Virtual Cards'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Something Else'));
      await tester.pumpAndSettle();
      expect(socket.sent, [
        [
          'option:choose',
          {'key': '__else'},
        ],
      ]);
      socket
        ..trigger('message', me('m2', 'Something Else'))
        ..trigger('message', bot('m3', 'Tell me more about it.'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Virtual Cards'), findsNothing);
      await page.finish(tester);
    },
  );

  testWidgets(
    '"Did this solve it?" offers That solved it and Talk to a person',
    (tester) async {
      final (page, socket) = await open(
        tester,
        first: snapshot(
          status: 'bot',
          messages: [
            bot('m1', 'Refunds take 3 days. Did this solve it?', confirm: true),
          ],
        ),
      );
      expect(find.text('Talk to a person'), findsOneWidget);
      await tester.tap(find.text('That solved it'));
      await tester.tap(find.text('Talk to a person'));
      await tester.pumpAndSettle();
      expect(socket.sent, [
        [
          'resolution:confirm',
          {'solved': true},
        ],
        ['handoff:request', <String, Object?>{}],
      ]);
      await page.finish(tester);
    },
  );

  testWidgets('"Reconnecting…" while reconnecting, and the rate-limit notice', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    socket.trigger('disconnect', 'transport close');
    await tester.pumpAndSettle();
    expect(find.text('Reconnecting…'), findsOneWidget);
    socket.trigger('chat_error', {
      'code': 'RATE_LIMITED',
      'retry_after_seconds': 20,
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Too many messages. Try again in a minute.'),
      findsOneWidget,
    );
    await page.finish(tester);
  });

  testWidgets(
    'a closed ticket shows the closed line, and Start a new conversation starts anew',
    (tester) async {
      final (page, socket) = await open(
        tester,
        first: snapshot(
          status: 'live',
          ticketId: 'fe0000000000fe0f95',
          messages: [me('m1', 'Why is my account not verified yet?')],
        ),
      );
      socket.trigger('ended', {'reason': 'ticket_closed'});
      await tester.pumpAndSettle();
      expect(find.text('This conversation was closed.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Start a new conversation'));
      await tester.pumpAndSettle();
      expect(page.sockets, hasLength(2));
      expect(find.text('This conversation was closed.'), findsNothing);
      await page.finish(tester);
    },
  );

  testWidgets('a message arriving twice shows once', (tester) async {
    final (page, socket) = await open(tester);
    socket
      ..trigger('message', me('m9', 'Is anyone there?'))
      ..trigger('message', me('m9', 'Is anyone there?'));
    await tester.pumpAndSettle();
    expect(find.text('Is anyone there?'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets('the box sends the customer\'s message and empties', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    await tester.enterText(find.byType(TextField), 'Where is my card?');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(socket.sent, [
      [
        'message',
        {'content': 'Where is my card?'},
      ],
    ]);
    expect(find.text('Where is my card?'), findsNothing);
    await page.finish(tester);
  });

  testWidgets(
    'attachments: photos and PDFs up to 10 MB go to the ticket; others are refused',
    (tester) async {
      var next = UploadFile(
        'statement.pdf',
        List.filled(11 << 20, 0),
        'application/pdf',
      );
      final (page, _) = await open(
        tester,
        first: snapshot(status: 'live', ticketId: 't1'),
        pickAttachment: (from) async => next,
      );
      Future<void> attach(String from) async {
        await tester.tap(find.bySemanticsLabel('Attach'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(from));
        await tester.pumpAndSettle();
      }

      await attach('File');
      expect(find.text('Files can be up to 10 MB.'), findsOneWidget);
      next = UploadFile('notes.txt', [1, 2, 3], 'text/plain');
      await attach('File');
      expect(find.text('Photos and PDFs only.'), findsOneWidget);
      expect(page.api.attached, isEmpty);

      next = UploadFile('card.jpg', [1, 2, 3], 'image/jpeg');
      await attach('Photo');
      expect(page.api.attached.single.ticketId, 't1');
      expect(page.api.attached.single.names, ['card.jpg']);
      expect(find.text('Photos and PDFs only.'), findsNothing);
      await page.finish(tester);
    },
  );

  testWidgets('nothing overflows at 200 % text', (tester) async {
    final (page, socket) = await open(
      tester,
      textScale: 2,
      first: snapshot(
        messages: [
          bot(
            'm1',
            'Hello Chukwu 👋, this is Callie from Davopay. Please choose the '
                'option that best matches your request.',
            options: [
              ('t1', 'Virtual Cards (Creation, Funding, Refunds)'),
              ('t2', 'Withdrawals to a Bank Account'),
            ],
          ),
        ],
      ),
    );
    socket.trigger('human_joined', {
      'display_name': 'Maryanne Okonkwo-Adeyemi',
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await page.finish(tester);
  });
}
