import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/features/help/article_page.dart';
import 'package:davodesk_flutter/src/ui/features/help/collection_page.dart';
import 'package:davodesk_flutter/src/ui/features/help/help_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/pages.dart';

FakeApi helpCentre() => FakeApi()
  ..categories = [
    {
      'id': 'c1',
      'name': 'Virtual cards',
      'description': 'Creating, funding and refunds',
      'article_count': 2,
      'sections': <Object?>[],
    },
    {
      'id': 'c2',
      'name': 'Withdrawals',
      'description': '',
      'article_count': 1,
      'sections': <Object?>[],
    },
  ]
  ..hits = [
    {
      'article_id': 'a1',
      'title': 'How refunds work',
      'excerpt': 'A refund goes back to the card in 3 days.',
    },
  ]
  ..collectionArticles = {
    'c1': [
      {
        'id': 'a1',
        'title': 'How refunds work',
        'body': '…',
        'category_id': 'c1',
      },
      {'id': 'a2', 'title': 'Funding a card', 'body': '…', 'category_id': 'c1'},
    ],
  }
  ..articlesById = {
    'a1': {
      'id': 'a1',
      'title': 'How refunds work',
      'body': 'A refund goes back to the card in 3 days.',
      'category_id': 'c1',
    },
  };

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('lists the collections, and leads into one', (tester) async {
    final page = await pumpPage(tester, HelpPage.new, api: helpCentre());
    expect(find.text('Search help articles'), findsOneWidget);
    expect(find.text('Virtual cards'), findsOneWidget);
    expect(find.text('Withdrawals'), findsOneWidget);
    await tester.tap(find.text('Virtual cards'));
    expect(page.went, [
      isA<CollectionPlace>()
          .having((place) => place.id, 'id', 'c1')
          .having((place) => place.name, 'name', 'Virtual cards'),
    ]);
    await page.finish(tester);
  });

  testWidgets('search shows the hits, and a hit leads to its article', (
    tester,
  ) async {
    final page = await pumpPage(tester, HelpPage.new, api: helpCentre());
    await tester.enterText(find.byType(TextField), 'refund');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(page.api.searches, ['refund']);
    expect(find.text('How refunds work'), findsOneWidget);
    expect(find.text('Virtual cards'), findsNothing);
    await tester.tap(find.text('How refunds work'));
    expect(page.went, [
      isA<ArticlePlace>().having((place) => place.id, 'id', 'a1'),
    ]);
    await page.finish(tester);
  });

  testWidgets('a collection lists its articles', (tester) async {
    final page = await pumpPage(
      tester,
      () => const CollectionPage(id: 'c1', name: 'Virtual cards'),
      api: helpCentre(),
    );
    expect(find.text('Virtual cards'), findsOneWidget);
    expect(find.text('Funding a card'), findsOneWidget);
    await tester.tap(find.text('How refunds work'));
    expect(page.went, [
      isA<ArticlePlace>().having((place) => place.id, 'id', 'a1'),
    ]);
    await page.finish(tester);

    final empty = await pumpPage(
      tester,
      () => const CollectionPage(id: 'c2', name: 'Withdrawals'),
      api: helpCentre(),
    );
    expect(find.text('No articles here yet.'), findsOneWidget);
    await empty.finish(tester);
  });

  testWidgets(
    'an article keeps Powered by DavoDesk at the bottom of the screen',
    (tester) async {
      final page = await pumpPage(
        tester,
        () => const ArticlePage(id: 'a1'),
        api: helpCentre(),
      );
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getBottomLeft(find.text('Powered by DavoDesk')).dy,
        greaterThan(screen - 40),
      );
      await page.finish(tester);
    },
  );

  testWidgets('an article asks "Was this helpful?", and a vote is sent', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      () => const ArticlePage(id: 'a1'),
      api: helpCentre(),
    );
    expect(find.text('How refunds work'), findsOneWidget);
    expect(
      find.text('A refund goes back to the card in 3 days.'),
      findsOneWidget,
    );
    expect(find.text('Was this helpful?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(page.api.votes, [('a1', true)]);
    expect(find.text('Thanks for telling us.'), findsOneWidget);
    await page.finish(tester);
  });

  testWidgets('nothing overflows at 200 % text', (tester) async {
    final page = await pumpPage(
      tester,
      HelpPage.new,
      api: helpCentre(),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await page.finish(tester);
  });
}
