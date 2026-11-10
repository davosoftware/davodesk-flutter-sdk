import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Wraps an SDK page in its own `material_ui` theme and localizations, so it works
/// inside an app on either Material, or on none.
///
/// The SDK's words are English, so the page's locale is too.
class SupportShell extends StatelessWidget {
  /// Creates the shell around [child], in [colors].
  const SupportShell({super.key, required this.colors, required this.child});

  /// The page's colours.
  final SupportColors colors;

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) => Localizations(
    locale: const Locale('en', 'US'),
    delegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    child: SupportColorsScope(
      colors: colors,
      // Status bar icons that read on the page; Home sets its own over the accent.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: colors.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Theme(data: _themeOf(colors), child: child),
      ),
    ),
  );
}

ThemeData _themeOf(SupportColors colors) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: colors.accent,
    brightness: colors.brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    surface: colors.paper,
    onSurface: colors.ink,
    onSurfaceVariant: colors.ink2,
    outlineVariant: colors.rule,
  ),
  fontFamily: colors.fontFamily,
  scaffoldBackgroundColor: colors.shelf,
  cardTheme: CardThemeData(
    color: colors.paper,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  dividerTheme: DividerThemeData(color: colors.rule, space: 1, thickness: 1),
  materialTapTargetSize: MaterialTapTargetSize.padded,
);
