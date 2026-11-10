import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/contact/contact_page.dart';
import 'package:davodesk_flutter/src/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/pages.dart';

const davopay = DavoDeskContactForm(
  note: 'We typically respond within 24 hours.',
  extraField: DavoDeskFormField(label: 'Order ID', hint: 'e.g. #VP-8291'),
);

Future<PageHarness> openContact(
  WidgetTester tester, {
  DavoDeskContactForm? form = davopay,
  FakeApi? api,
}) => pumpPage(tester, ContactPage.new, api: api, contactForm: form);

Future<void> fill(WidgetTester tester, {String order = ''}) async {
  await tester.enterText(find.byKey(const Key('subject')), 'Card declined');
  if (order.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('extra')), order);
  }
  await tester.enterText(find.byKey(const Key('message')), 'My card…');
  await tester.pump();
}

FilledButton sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('the words, the note\'s card, and the optional field', (
    tester,
  ) async {
    final page = await openContact(tester);
    for (final words in [
      'Send us a message',
      'Have a question about your order or our services? Our team is here to help.',
      'Subject',
      'Message',
      'Send',
      'We typically respond within 24 hours.',
      'Order ID',
      'OPTIONAL',
    ]) {
      expect(find.text(words), findsOneWidget, reason: words);
    }
    // The reply comes to Messages, so the form never speaks of email.
    expect(
      find.textContaining(RegExp('email', caseSensitive: false)),
      findsNothing,
    );
    await page.finish(tester);

    final plain = await openContact(tester, form: null);
    expect(find.text('OPTIONAL'), findsNothing);
    expect(find.text('We typically respond within 24 hours.'), findsNothing);
    expect(find.text('Subject'), findsOneWidget);
    await plain.finish(tester);
  });

  testWidgets('Send waits for a subject and a message', (tester) async {
    final page = await openContact(tester);
    expect(sendButton(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('subject')), 'Card declined');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('message')), 'My card…');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);
    await page.finish(tester);
  });

  testWidgets(
    'sending raises the ticket with the extra line, says so, and opens it',
    (tester) async {
      final page = await openContact(
        tester,
        api: FakeApi()..raisedTicketId = 'a0000000000000c0ffee',
      );
      await fill(tester, order: '#VP-8291');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(page.api.raised.single.body, {
        'subject': 'Card declined',
        'message': 'Order ID: #VP-8291\n\nMy card…',
      });
      expect(find.text('Sent. We’ll reply in Messages.'), findsOneWidget);
      expect(page.went, [
        isA<TicketPlace>().having(
          (place) => place.id,
          'id',
          'a0000000000000c0ffee',
        ),
      ]);
      await page.finish(tester);
    },
  );

  testWidgets('a sent form empties, so it is not sent twice', (tester) async {
    final page = await openContact(tester);
    await fill(tester, order: '#VP-8291');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Sent. We’ll reply in Messages.'), findsOneWidget);
    expect(find.text('Card declined'), findsNothing);
    expect(find.text('#VP-8291'), findsNothing);
    expect(find.text('My card…'), findsNothing);
    expect(sendButton(tester).onPressed, isNull);
    await page.finish(tester);
  });

  testWidgets('a message added to an open request says which', (tester) async {
    final page = await openContact(
      tester,
      api: FakeApi()
        ..raisedTicketId = 'a0000000000000c0ffee'
        ..raiseResumes = true,
    );
    await fill(tester);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Added to your open request #C0FFEE'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets('a double tap sends once', (tester) async {
    final page = await openContact(tester);
    await fill(tester);
    await tester.tap(find.text('Send'));
    await tester.tap(find.text('Send'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(page.api.raised, hasLength(1));
    await page.finish(tester);
  });

  testWidgets('a refusal shows in place and keeps the text', (tester) async {
    final page = await openContact(
      tester,
      api: FakeApi()..refuseNextRaise = 422,
    );
    await fill(tester, order: '#VP-8291');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong here.'), findsOneWidget);
    expect(find.text('Card declined'), findsOneWidget);
    expect(find.text('#VP-8291'), findsOneWidget);
    expect(find.text('My card…'), findsOneWidget);
    expect(page.went, isEmpty);
    expect(sendButton(tester).onPressed, isNotNull);
    await page.finish(tester);
  });

  testWidgets('nothing overflows at 200 % text', (tester) async {
    final page = await pumpPage(
      tester,
      ContactPage.new,
      contactForm: davopay,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await page.finish(tester);
  });
}
