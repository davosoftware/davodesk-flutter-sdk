import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/ui/core/support_shell.dart';
import 'package:davodesk_flutter/src/ui/theme.dart';
import 'package:davodesk_flutter/src/ui/widgets/brand_tile.dart';
import 'package:davodesk_flutter/src/ui/widgets/header_logo.dart';
import 'package:davodesk_flutter/src/ui/widgets/powered_by.dart';
import 'package:davodesk_flutter/src/ui/widgets/recover.dart';
import 'package:davodesk_flutter/src/ui/widgets/state_chip.dart';
import 'package:davodesk_flutter/src/ui/words.dart';
import 'package:flutter/material.dart' as framework;
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
