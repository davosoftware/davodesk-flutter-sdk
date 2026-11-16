import 'dart:async';

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/conversation/conversation_page.dart';
import 'package:davodesk_flutter/src/ui/widgets/slide_in.dart';
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
  bool? ai,
}) => {
  'id': id,
  'sender_type': 'bot',
  'content': content,
  'options': [
    for (final (key, label) in options) {'key': key, 'label': label},
  ],
  'confirmation_requested': confirm,
  'ai_written': ?ai,
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
      // The header, and the greeting's run head.
      expect(find.text('Callie'), findsNWidgets(2));
      expect(find.text('The team can also help'), findsOneWidget);
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

  testWidgets(
    "a greeting and an AI answer with its follow-up show the bot's name twice and ✦ once",
    (tester) async {
      final (page, _) = await open(
        tester,
        first: snapshot(
          messages: [
            bot('m1', 'Hi Chukwu, how can we help today?', ai: false),
            me('m2', 'Where is my refund?'),
            bot('m3', 'Refunds take 3 days to reach your card.', ai: true),
            bot('m4', 'You can see it under Payments.', ai: true),
          ],
        ),
      );
      final inChat = find.byType(RefreshIndicator);
      expect(
        find.descendant(of: inChat, matching: find.text('Callie')),
        findsNWidgets(2),
      );
      // The list reads each bubble as one: "Callie, Written by AI, Refunds take…".
      expect(find.bySemanticsLabel(RegExp('Written by AI')), findsOneWidget);
      expect(find.textContaining('AI Agent'), findsNothing);
      await page.finish(tester);
    },
  );

  testWidgets('"{name} joined" sits just before their first message', (
    tester,
  ) async {
    final (page, socket) = await open(
      tester,
      first: snapshot(
        status: 'live',
        ticketId: '6a0000000000009bbc55',
        messages: [
          me('m1', 'My refund hasn’t come back'),
          bot('m2', 'I’ll pass you to the team.'),
          {
            'id': 'm3',
            'sender_type': 'staff',
            'sender_display_name': 'Mara',
            'content': 'It’s back on your card now.',
          },
        ],
      ),
    );
    socket.trigger('human_joined', {'display_name': 'Mara'});
    await tester.pumpAndSettle();
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('I’ll pass you to the team.'), lessThan(top('Mara joined')));
    expect(top('Mara joined'), lessThan(top('It’s back on your card now.')));
    await page.finish(tester);
  });

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
    'a closed ticket shows the closed line, and Start a new chat starts anew',
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
      expect(find.text('This chat was closed.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Start a new chat'));
      await tester.pumpAndSettle();
      expect(page.sockets, hasLength(2));
      expect(find.text('This chat was closed.'), findsNothing);
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
        {'content': 'Where is my card?', 'client_id': isA<String>()},
      ],
    ]);
    // The box empties; the message itself shows as sending (app feedback spec §1).
    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.text('Where is my card?'),
      ),
      findsNothing,
    );
    await page.finish(tester);
  });

  testWidgets('a message shows at once as Sending…, then as sent', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    await tester.enterText(find.byType(TextField), 'Where is my card?');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Where is my card?'), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);

    final clientId =
        (socket.sent.single[1]! as Map<String, Object?>)['client_id'];
    socket.trigger('message', {
      'id': 'm2',
      'sender_type': 'end_user',
      'content': 'Where is my card?',
      'client_id': clientId,
    });
    await tester.pumpAndSettle();
    expect(find.text('Sending…'), findsNothing);
    expect(find.text('Where is my card?'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets(
    'DavoDesk AI typing shows under its head and goes with its answer',
    (tester) async {
      final (page, socket) = await open(tester);
      socket.trigger('typing', {'by': 'ai', 'typing': true});
      // Not pumpAndSettle: the dots never settle while they show.
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('Callie is typing')), findsOneWidget);

      socket.trigger('message', {
        'id': 'm2',
        'sender_type': 'bot',
        'content': 'Here is how.',
      });
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('Callie is typing')), findsNothing);
      await page.finish(tester);
    },
  );

  testWidgets(
    "the team's typing shows the member's name and goes after 8 seconds",
    (tester) async {
      final (page, socket) = await open(tester);
      socket.trigger('typing', {'by': 'team', 'typing': true, 'name': 'Mara'});
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('Mara is typing')), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      expect(find.bySemanticsLabel(RegExp('Mara is typing')), findsNothing);
      await page.finish(tester);
    },
  );

  // App feedback spec §8. Short lines first and long ones after, as a real chat runs: a
  // list that guesses its length from the lines it has built falls short of the end.
  Map<String, Object?> longChat() => snapshot(
    messages: [
      for (var i = 0; i < 25; i++) bot('m$i', 'Line $i.'),
      for (var i = 25; i < 32; i++) bot('m$i', 'A long answer $i. ' * 24),
    ],
  );
  const longAnswer = {
    'id': 'mx',
    'sender_type': 'bot',
    'content':
        'Another long answer. Another long answer. Another long answer. '
        'Another long answer. Another long answer. Another long answer. '
        'Another long answer. Another long answer. The newest line',
  };

  /// Whether [line]'s end, its newest words, is on screen in the chat.
  void expectInView(WidgetTester tester, Finder line) {
    expect(line, findsOneWidget);
    final chat = tester.getRect(find.byType(RefreshIndicator));
    expect(tester.getRect(line).bottom, lessThanOrEqualTo(chat.bottom));
    expect(tester.getRect(line).bottom, greaterThan(chat.top));
  }

  testWidgets('in a long chat, a new line is in view', (tester) async {
    final (page, socket) = await open(tester, first: longChat());
    socket.trigger('message', longAnswer);
    await tester.pumpAndSettle();
    expectInView(tester, find.textContaining('The newest line'));
    await page.finish(tester);
  });

  testWidgets(
    'in a long chat, the typing dots and the answer after them are in view',
    (tester) async {
      final (page, socket) = await open(tester, first: longChat());
      socket.trigger('typing', {'by': 'ai', 'typing': true});
      await tester.pump();
      await tester.pump();
      expectInView(tester, find.bySemanticsLabel(RegExp('Callie is typing')));

      // The answer takes the dots' place: as many lines as before, the last one new.
      socket.trigger('message', longAnswer);
      await tester.pumpAndSettle();
      expectInView(tester, find.textContaining('The newest line'));
      await page.finish(tester);
    },
  );

  testWidgets(
    'in a long chat, a message refused after "Sending…" shows its Retry in view',
    (tester) async {
      final (page, socket) = await open(tester, first: longChat());
      final refusal = Completer<Object?>();
      socket.answers['message'] = refusal.future;
      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Sending…'), findsOneWidget);

      refusal.complete({'ok': false});
      await tester.pumpAndSettle();
      // The whole button, not just its word: "Not sent · Retry" is taller.
      expectInView(tester, find.widgetWithText(TextButton, 'Retry'));
      await page.finish(tester);
    },
  );

  testWidgets('when the keyboard opens, the newest line stays in view', (
    tester,
  ) async {
    final (page, socket) = await open(tester, first: longChat());
    socket.trigger('message', longAnswer);
    await tester.pumpAndSettle();
    // 300 logical pixels of keyboard, at the harness's 3 pixels each.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    expectInView(tester, find.textContaining('The newest line'));
    await page.finish(tester);
  });

  Finder slidingIn(Finder line) =>
      find.ancestor(of: line, matching: find.byType(SlideIn));
  Finder dots() => find.bySemanticsLabel(RegExp('Callie is typing'));

  testWidgets(
    "the customer's message slides in as Sending…, not again as sent",
    (tester) async {
      final (page, socket) = await open(tester);
      final echo = Completer<Object?>();
      socket.answers['message'] = echo.future;
      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump();
      expect(slidingIn(find.text('Hello?')), findsOneWidget);
      await tester.pumpAndSettle();

      socket.trigger('message', me('m2', 'Hello?'));
      echo.complete({'ok': true});
      // A line that slid in keeps its SlideIn, so settling hides nothing.
      await tester.pumpAndSettle();
      expect(find.text('Sending…'), findsNothing);
      expect(slidingIn(find.text('Hello?')), findsNothing);
      await page.finish(tester);
    },
  );

  testWidgets(
    'dots there when the chat opens stay still, and slide in when they come back',
    (tester) async {
      final page = await pumpPage(tester, ConversationPage.new, api: chatApi());
      final socket = page.sockets.single
        ..trigger('session', snapshot(messages: [bot('m1', 'Hello')]))
        ..trigger('typing', {'by': 'ai', 'typing': true});
      await tester.pump();
      await tester.pump();
      expect(dots(), findsOneWidget);
      expect(slidingIn(dots()), findsNothing);

      socket.trigger('message', bot('m2', 'Here is how.'));
      await tester.pump();
      socket.trigger('typing', {'by': 'ai', 'typing': true});
      await tester.pump();
      await tester.pump();
      expect(slidingIn(dots()), findsOneWidget);
      await page.finish(tester);
    },
  );

  testWidgets('a new bubble slides in, unless the phone asks for less motion', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    socket.trigger('message', {
      'id': 'm2',
      'sender_type': 'bot',
      'content': 'Here is how.',
    });
    await tester.pump();
    await tester.pump();
    expect(slidingIn(find.text('Here is how.')), findsOneWidget);
    // What the chat showed when it opened stays still.
    expect(slidingIn(find.text('Hello')), findsNothing);
    await tester.pumpAndSettle();

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    socket.trigger('message', {
      'id': 'm3',
      'sender_type': 'bot',
      'content': 'And one more.',
    });
    await tester.pumpAndSettle();
    expect(slidingIn(find.text('And one more.')), findsNothing);
    await page.finish(tester);
  });

  // App feedback spec §3.
  testWidgets('pulling the chat down asks for a fresh snapshot', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(socket.sent, [
      ['session:sync', <String, Object?>{}],
    ]);
    await page.finish(tester);
  });

  testWidgets('a refused send offers Retry, which sends it again', (
    tester,
  ) async {
    final (page, socket) = await open(tester);
    socket.answers['message'] = {'ok': false};
    await tester.enterText(find.byType(TextField), 'Hello?');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsOneWidget);

    socket.answers.remove('message');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(socket.sent, hasLength(2));
    final ids = [
      for (final sent in socket.sent)
        (sent[1]! as Map<String, Object?>)['client_id'],
    ];
    expect(ids[0], isNot(ids[1]));
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('Hello?'), findsOneWidget);
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
