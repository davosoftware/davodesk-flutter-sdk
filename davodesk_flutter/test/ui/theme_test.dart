import 'package:davodesk_flutter/src/ui/core/support_shell.dart';
import 'package:davodesk_flutter/src/ui/theme.dart';
import 'package:davodesk_flutter/src/ui/widgets/state_chip.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
}
