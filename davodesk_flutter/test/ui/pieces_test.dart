import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/ui/core/support_shell.dart';
import 'package:davodesk_flutter/src/ui/features/conversation/conversation_view_model.dart';
import 'package:davodesk_flutter/src/ui/theme.dart';
import 'package:davodesk_flutter/src/ui/widgets/brand_tile.dart';
import 'package:davodesk_flutter/src/ui/widgets/header_logo.dart';
import 'package:davodesk_flutter/src/ui/widgets/message_bubble.dart';
import 'package:davodesk_flutter/src/ui/widgets/powered_by.dart';
import 'package:davodesk_flutter/src/ui/widgets/recover.dart';
import 'package:davodesk_flutter/src/ui/widgets/state_chip.dart';
import 'package:davodesk_flutter/src/ui/words.dart';
import 'package:flutter/material.dart' as framework;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const blue = Color(0xFF1D4ED8);

ChannelConfig config({String? accent}) => ChannelConfig(
  channelId: 'ch_1',
  type: 'app',
  brandName: 'Davopay',
  supportMode: 'ai_triage',
  appearance: accent == null ? null : ChannelLook(accentColor: accent),
);

/// [child] on an SDK page, as the support routes host it.
Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
    MediaQuery(
      data: const MediaQueryData(),
      child: SupportShell(
        colors: SupportColors.from(accent: blue, brightness: brightness),
        child: Material(child: Center(child: child)),
      ),
    );

/// The colours [SupportColors.resolve] gives under a phone set to [platform].
Future<SupportColors> resolved(
  WidgetTester tester, {
  Brightness platform = Brightness.light,
  ChannelConfig? channel,
  DavoDeskTheme? theme,
}) async {
  late SupportColors colors;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(platformBrightness: platform),
      child: Builder(
        builder: (context) {
          colors = SupportColors.resolve(
            context,
            config: channel,
            theme: theme,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return colors;
}

void main() {
  test('words: references, the team, first names and who spoke', () {
    expect(referenceOf('6a0000000000009bbc55'), '#9BBC55');
    expect(referenceOf('ab1'), '#AB1');
    expect(teamName('Davopay'), 'Davopay team');
    expect(firstNameOf('Chukwu Obi'), 'Chukwu');
    expect(firstNameOf('  '), isNull);
    expect(firstNameOf(null), isNull);
    String who(SenderType type, [String? name]) =>
        speakerName(type, name, brand: 'Davopay', aiName: 'Callie');
    expect(who(.endUser), 'You');
    expect(who(.bot), 'Callie');
    expect(who(.staff, 'Mara'), 'Mara');
    expect(who(.staff, ' '), 'Davopay team');
    expect(who(.automation), 'Davopay team');
  });

  test('heads each run of the bot, and starts a run when the kind changes', () {
    ChatMessage message(String sender, {bool? ai}) => ChatMessage.fromJson({
      'id': 'm',
      'sender_type': sender,
      'content': 'Hi',
      'ai_written': ?ai,
    });
    final bot = message('bot');
    final me = message('end_user');
    expect(botHeads([bot, bot, me, bot]), [true, false, false, true]);
    final answer = message('bot', ai: true);
    final greeting = message('bot', ai: false);
    expect(botHeads([answer, answer, greeting]), [true, false, true]);
    // An API from before the field: the same kind as a greeting.
    expect(botHeads([bot, greeting]), [true, false]);
  });

  testWidgets('BrandTile shows the initial when the image errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const BrandTile(logoUrl: 'https://cdn.test/logo.png', name: 'davopay'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('D'), findsOneWidget);

    await tester.pumpWidget(host(const BrandTile(logoUrl: null, name: 'Acme')));
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('HeaderLogo shows the name without a URL, or when it fails', (
    tester,
  ) async {
    await tester.pumpWidget(host(const HeaderLogo(url: null, name: 'Davopay')));
    expect(find.text('Davopay'), findsOneWidget);

    await tester.pumpWidget(
      host(
        const HeaderLogo(url: 'https://cdn.test/wordmark.png', name: 'Acme'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);
  });

  testWidgets('StateChip labels the six ticket states as the web does', (
    tester,
  ) async {
    const labels = {
      'open': 'Open',
      'in_progress': 'Open',
      'escalated': 'Open',
      'pending': 'Reply',
      'resolved': 'Solved',
      'closed': 'Closed',
      'something_new': 'Open',
    };
    for (final MapEntry(key: status, value: label) in labels.entries) {
      await tester.pumpWidget(host(StateChip(status: status)));
      expect(find.text(label), findsOneWidget, reason: status);
    }
  });

  testWidgets('the shell gives the status bar icons that read on the page', (
    tester,
  ) async {
    Brightness? icons() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        )
        .value
        .statusBarIconBrightness;
    await tester.pumpWidget(host(const SizedBox()));
    expect(icons(), Brightness.dark);
    await tester.pumpWidget(
      host(const SizedBox(), brightness: Brightness.dark),
    );
    expect(icons(), Brightness.light);
  });

  testWidgets("a person's avatar letter is a capital", (tester) async {
    await tester.pumpWidget(
      host(
        const MessageBubble(
          item: BubbleItem(id: 'm1', text: 'Hi Ada', label: 'superchidi'),
          maxWidth: 300,
        ),
      ),
    );
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets(
    "a head shows the logo, the bot's name and ✦ when the AI wrote it",
    (tester) async {
      const logo = 'https://cdn.test/logo.png';
      await tester.pumpWidget(
        host(
          const MessageBubble(
            item: BubbleItem(
              id: 'm1',
              text: 'Refunds take 3 days.',
              label: 'Callie',
              head: true,
              ai: true,
              brand: 'Davopay',
              logoUrl: logo,
            ),
            maxWidth: 300,
          ),
        ),
      );
      final tile = find.byType(BrandTile);
      expect(tester.getSize(tile), const Size(18, 18));
      expect(
        find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is NetworkImage &&
                (widget.image as NetworkImage).url == logo,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Callie'), findsOneWidget);
      expect(find.bySemanticsLabel('Written by AI'), findsOneWidget);
      expect(find.textContaining('AI Agent'), findsNothing);
    },
  );

  testWidgets("a head without a logo shows the brand's initial in its colour", (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const MessageBubble(
          item: BubbleItem(
            id: 'm1',
            text: 'Hi Chukwu, how can we help today?',
            label: 'Callie',
            head: true,
            brand: 'Davopay',
          ),
          maxWidth: 300,
        ),
      ),
    );
    final initial = find.descendant(
      of: find.byType(BrandTile),
      matching: find.text('D'),
    );
    expect(initial, findsOneWidget);
    expect(tester.widget<Text>(initial).style?.color, blue);
    expect(find.text('Callie'), findsOneWidget);
    // People wrote the greeting: no ✦.
    expect(find.bySemanticsLabel(RegExp('Written by AI')), findsNothing);
  });

  testWidgets('a bubble that is not a head has no label row', (tester) async {
    final followUp = bubbleOf(
      ChatMessage.fromJson({
        'id': 'm2',
        'sender_type': 'bot',
        'content': 'Anything else?',
        'ai_written': true,
      }),
      brand: 'Davopay',
      ai: 'Callie',
      logoUrl: 'https://cdn.test/logo.png',
    );
    await tester.pumpWidget(host(MessageBubble(item: followUp, maxWidth: 300)));
    expect(find.text('Anything else?'), findsOneWidget);
    expect(find.byType(BrandTile), findsNothing);
    expect(find.text('Callie'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Written by AI')), findsNothing);
  });

  testWidgets('PoweredBy shows the DavoDesk mark and words', (tester) async {
    await tester.pumpWidget(host(const PoweredBy()));
    expect(find.text('Powered by DavoDesk'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Recover offers Start again', (tester) async {
    var retries = 0;
    await tester.pumpWidget(host(Recover(onRetry: () => retries++)));
    expect(find.text('Something went wrong here.'), findsOneWidget);
    await tester.tap(find.text('Start again'));
    expect(retries, 1);
  });

  testWidgets('the accent: DavoDeskTheme, then the channel, then blue', (
    tester,
  ) async {
    expect(
      (await resolved(
        tester,
        channel: config(accent: '#0f766e'),
        theme: const DavoDeskTheme(accent: Color(0xFF7C3AED)),
      )).accent,
      const Color(0xFF7C3AED),
    );
    expect(
      (await resolved(tester, channel: config(accent: '#0f766e'))).accent,
      const Color(0xFF0F766E),
    );
    expect((await resolved(tester, channel: config())).accent, blue);
    expect((await resolved(tester)).accent, blue);
  });

  testWidgets(
    'DavoDeskTheme.brightness beats the phone; without it, the phone',
    (tester) async {
      final dark = await resolved(tester, platform: .dark);
      expect(dark.brightness, Brightness.dark);
      expect(dark.shelf, const Color(0xFF0B0D12));
      expect(dark.paper, const Color(0xFF14171D));
      expect(
        (await resolved(
          tester,
          theme: const DavoDeskTheme(brightness: .dark),
        )).brightness,
        Brightness.dark,
      );
      expect(
        (await resolved(
          tester,
          platform: .dark,
          theme: const DavoDeskTheme(brightness: .light),
        )).brightness,
        Brightness.light,
      );
    },
  );

  testWidgets(
    'inside a framework-Material host, an SDK page renders and takes text',
    (tester) async {
      Color? primary;
      await tester.pumpWidget(
        framework.MaterialApp(
          home: Builder(
            builder: (context) => SupportShell(
              colors: SupportColors.resolve(context),
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    primary = Theme.of(context).colorScheme.primary;
                    return const TextField(key: Key('box'));
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('box')),
        'Where is my order?',
      );
      await tester.pump();
      expect(find.text('Where is my order?'), findsOneWidget);
      expect(primary, blue);
    },
  );
}
