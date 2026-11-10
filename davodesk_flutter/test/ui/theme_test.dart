import 'package:davodesk_flutter/src/ui/core/support_shell.dart';
import 'package:davodesk_flutter/src/ui/features/contact/contact_page.dart';
import 'package:davodesk_flutter/src/ui/features/conversation/conversation_view_model.dart';
import 'package:davodesk_flutter/src/ui/features/home/home_page.dart';
import 'package:davodesk_flutter/src/ui/features/messages/messages_page.dart';
import 'package:davodesk_flutter/src/ui/theme.dart';
import 'package:davodesk_flutter/src/ui/widgets/message_bubble.dart';
import 'package:davodesk_flutter/src/ui/widgets/state_chip.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_api.dart';
import '../support/pages.dart';

const blue = Color(0xFF1D4ED8);

const acme = DavoDeskTheme(
  light: DavoDeskColors(
    background: Color(0xFFFAFAF7),
    surface: Color(0xFFF0EFEA),
    text: Color(0xFF1B1B1F),
    border: Color(0xFFE2E0D8),
  ),
);

/// The colours [SupportColors.resolve] gives for [theme] under a phone set to [platform].
Future<SupportColors> resolved(
  WidgetTester tester, {
  Brightness platform = Brightness.light,
  DavoDeskTheme? theme,
}) async {
  late SupportColors colors;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(platformBrightness: platform),
      child: Builder(
        builder: (context) {
          colors = SupportColors.resolve(context, theme: theme);
          return const SizedBox();
        },
      ),
    ),
  );
  return colors;
}

/// WCAG contrast between two colours.
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

Color colorOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style!.color!;

void main() {
  testWidgets('a mode’s colours replace DavoDesk’s, and the rest follow them', (
    tester,
  ) async {
    final light = await resolved(tester, theme: acme);
    expect(light.paper, const Color(0xFFFAFAF7));
    expect(light.shelf, const Color(0xFFF0EFEA));
    expect(light.ink, const Color(0xFF1B1B1F));
    expect(light.rule, const Color(0xFFE2E0D8));
    expect(
      light.ink2,
      Color.lerp(const Color(0xFF1B1B1F), const Color(0xFFFAFAF7), 0.25),
    );
    expect(
      light.ink3,
      Color.lerp(const Color(0xFF1B1B1F), const Color(0xFFFAFAF7), 0.55),
    );

    final dark = await resolved(tester, platform: .dark, theme: acme);
    expect(dark.paper, const Color(0xFF14171D));
    expect(dark.shelf, const Color(0xFF0B0D12));
    expect(dark.ink, const Color(0xFFE8EBF2));
  });

  testWidgets('a colour left out keeps DavoDesk’s', (tester) async {
    final colors = await resolved(
      tester,
      theme: const DavoDeskTheme(
        light: DavoDeskColors(background: Color(0xFFFAFAF7)),
      ),
    );
    expect(colors.paper, const Color(0xFFFAFAF7));
    expect(colors.shelf, const Color(0xFFF5F6F8));
    expect(colors.ink, const Color(0xFF0F172A));
    expect(colors.ink2, const Color(0xFF475569));
  });

  testWidgets('a mode’s accent beats the theme’s', (tester) async {
    const theme = DavoDeskTheme(
      accent: Color(0xFF7C3AED),
      dark: DavoDeskColors(accent: Color(0xFFA78BFA)),
    );
    expect(
      (await resolved(tester, platform: .dark, theme: theme)).accent,
      const Color(0xFFA78BFA),
    );
    expect(
      (await resolved(tester, theme: theme)).accent,
      const Color(0xFF7C3AED),
    );
  });

  testWidgets(
    'the accent as text reads at 4.5:1, in dark and with a pale accent',
    (tester) async {
      final dark = await resolved(tester, platform: .dark);
      expect(dark.accentInk, isNot(dark.accent));
      expect(
        contrast(dark.accentInk, dark.accentSoft),
        greaterThanOrEqualTo(4.5),
      );

      final pale = await resolved(
        tester,
        theme: const DavoDeskTheme(accent: Color(0xFFFFD600)),
      );
      expect(pale.accentInk, isNot(pale.accent));
      expect(
        contrast(pale.accentInk, pale.accentSoft),
        greaterThanOrEqualTo(4.5),
      );

      expect((await resolved(tester)).accentInk, blue);
    },
  );

  testWidgets('a text button and the Open chip draw in the readable accent', (
    tester,
  ) async {
    final colors = SupportColors.from(accent: blue, brightness: .dark);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: SupportShell(
          colors: colors,
          child: Material(
            child: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('Reopen it')),
                const StateChip(status: 'open'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(colorOf(tester, find.text('Reopen it')), colors.accentInk);
    expect(colorOf(tester, find.textContaining('Open')), colors.accentInk);
  });

  group('fonts and corners', () {
    setUp(
      () => SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty(),
    );

    String? fontOf(WidgetTester tester, Finder text) =>
        tester.renderObject<RenderParagraph>(text).text.style!.fontFamily;

    BoxDecoration decorationOf(WidgetTester tester, Finder finder) =>
        tester
                .widget<Container>(
                  find
                      .ancestor(of: finder, matching: find.byType(Container))
                      .first,
                )
                .decoration!
            as BoxDecoration;

    testWidgets('headings take the heading font, the rest the body font', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        MessagesPage.new,
        theme: const DavoDeskTheme(
          fontFamily: 'Inter',
          headingFontFamily: 'Poppins',
        ),
      );
      expect(fontOf(tester, find.text('Chats')), 'Poppins');
      expect(fontOf(tester, find.text('No chats yet')), 'Poppins');
      expect(
        fontOf(tester, find.text('Chats with the team will be shown here')),
        'Inter',
      );
      await page.finish(tester);

      final home = await pumpPage(
        tester,
        HomePage.new,
        theme: const DavoDeskTheme(
          fontFamily: 'Inter',
          headingFontFamily: 'Poppins',
        ),
      );
      expect(
        fontOf(tester, find.textContaining('How can we help?')),
        'Poppins',
      );
      await home.finish(tester);
    });

    testWidgets('the brand name over Home takes the heading font too', (
      tester,
    ) async {
      final home = await pumpPage(
        tester,
        HomePage.new,
        theme: const DavoDeskTheme(
          fontFamily: 'Inter',
          headingFontFamily: 'Poppins',
        ),
      );
      expect(fontOf(tester, find.text('Davopay')), 'Poppins');
      await home.finish(tester);
    });

    testWidgets('headings fall back to the body font', (tester) async {
      final colors = await resolved(
        tester,
        theme: const DavoDeskTheme(fontFamily: 'Inter'),
      );
      expect(colors.headingFontFamily, 'Inter');
    });

    testWidgets('square corners: chips, bubbles, cards, fields and buttons', (
      tester,
    ) async {
      final colors = SupportColors.from(
        accent: blue,
        brightness: .light,
        corners: .square,
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: SupportShell(
            colors: colors,
            child: Material(
              child: Column(
                children: [
                  const StateChip(status: 'open'),
                  const MessageBubble(
                    item: BubbleItem(id: 'm1', text: 'Hi Ada', mine: true),
                    maxWidth: 300,
                  ),
                  FilledButton(onPressed: () {}, child: const Text('Send')),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        decorationOf(tester, find.textContaining('Open')).borderRadius,
        BorderRadius.zero,
      );
      expect(
        decorationOf(tester, find.text('Hi Ada')).borderRadius,
        BorderRadiusDirectional.zero,
      );
      final button = tester.element(find.byType(FilledButton));
      expect(
        Theme.of(button).filledButtonTheme.style!.shape!.resolve({}),
        const RoundedRectangleBorder(),
      );

      final home = await pumpPage(
        tester,
        HomePage.new,
        theme: const DavoDeskTheme(corners: .square),
      );
      final card = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Chat with us'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (card.decoration as BoxDecoration).borderRadius,
        BorderRadius.zero,
      );
      await home.finish(tester);

      final contact = await pumpPage(
        tester,
        ContactPage.new,
        theme: const DavoDeskTheme(corners: .square),
      );
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('subject')),
          matching: find.byType(TextField),
          matchRoot: true,
        ),
      );
      expect(
        (field.decoration!.border! as OutlineInputBorder).borderRadius,
        BorderRadius.zero,
      );
      await contact.finish(tester);
    });

    testWidgets('rounded by default, and an avatar stays round when square', (
      tester,
    ) async {
      expect((await resolved(tester)).corner(16), BorderRadius.circular(16));
      final page = await pumpPage(
        tester,
        MessagesPage.new,
        api: FakeApi()..tickets = [ticketJson('6a0000000000009bbc55')],
        theme: const DavoDeskTheme(corners: .square),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
        findsWidgets,
      );
      await page.finish(tester);
    });
  });
}
