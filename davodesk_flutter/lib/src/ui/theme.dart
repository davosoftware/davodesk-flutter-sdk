import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme, ThemeData;

import '../domain/models.dart';

/// What DavoDesk's screens use when neither the app nor the channel sets an accent.
const defaultAccent = Color(0xFF1D4ED8);

/// How the support screens look, when the app wants a say.
///
/// Without it, the accent is the channel's, light or dark follows the app (an app on
/// `material_ui`) or the phone, and the font is the app's or the platform's.
class const DavoDeskTheme({
  final Color? accent,
  final Brightness? brightness,
  final String? fontFamily,
}) {
  /// Creates a [DavoDeskTheme].
  this;
}

/// The email form's words that belong to the app: [note], the line in the highlighted
/// card (no card without one), and an optional [extraField].
class const DavoDeskEmailForm({
  final String? note,
  final DavoDeskFormField? extraField,
}) {
  /// Creates a [DavoDeskEmailForm].
  this;
}

/// An extra field on the email form, such as an order number; its value goes first in
/// the message as "[label]: value".
class const DavoDeskFormField({
  required final String label,
  final String? hint,
}) {
  /// Creates a [DavoDeskFormField].
  this;
}

/// The support screens' colours: the approved mockup's, around one accent.
class const SupportColors({
  required final Brightness brightness,
  required final Color accent,
  required final Color accentSoft,
  required final Color onAccent,
  required final Color ink,
  required final Color ink2,
  required final Color ink3,
  required final Color rule,
  required final Color paper,
  required final Color shelf,
  required final Color ok,
  required final Color okSoft,
  required final Color warn,
  required final Color warnSoft,
  final String? fontFamily,
}) {
  /// Creates the colours.
  this;

  /// The mockup's colours for [brightness], around [accent].
  factory from({
    required Color accent,
    required Brightness brightness,
    String? fontFamily,
  }) {
    final dark = brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF14171D) : const Color(0xFFFFFFFF);
    return SupportColors(
      brightness: brightness,
      accent: accent,
      accentSoft: Color.lerp(paper, accent, dark ? 0.3 : 0.1)!,
      onAccent: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF0F172A),
      ink: dark ? const Color(0xFFE8EBF2) : const Color(0xFF0F172A),
      ink2: dark ? const Color(0xFFA4ADBF) : const Color(0xFF475569),
      ink3: dark ? const Color(0xFF6B7487) : const Color(0xFF94A3B8),
      rule: dark ? const Color(0xFF252A35) : const Color(0xFFE5E7EB),
      paper: paper,
      shelf: dark ? const Color(0xFF0B0D12) : const Color(0xFFF5F6F8),
      ok: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      okSoft: dark ? const Color(0xFF10301D) : const Color(0xFFDCFCE7),
      warn: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      warnSoft: dark ? const Color(0xFF3A2A0C) : const Color(0xFFFEF3C7),
      fontFamily: fontFamily,
    );
  }

  /// The colours for a page: [theme] first, then the channel's accent ([config]), then
  /// the app's `material_ui` theme, then the phone.
  static SupportColors resolve(
    BuildContext context, {
    ChannelConfig? config,
    DavoDeskTheme? theme,
  }) {
    final appBrightness = Theme.maybeBrightnessOf(context);
    return SupportColors.from(
      accent:
          theme?.accent ??
          _hex(config?.appearance?.accentColor) ??
          defaultAccent,
      brightness:
          theme?.brightness ??
          appBrightness ??
          MediaQuery.platformBrightnessOf(context),
      fontFamily:
          theme?.fontFamily ??
          (appBrightness == null
              ? null
              : Theme.of(context).textTheme.bodyMedium?.fontFamily),
    );
  }

  /// The colours of the page around [context].
  static SupportColors of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SupportColorsScope>();
    assert(scope != null, 'An SDK piece is outside a SupportShell.');
    return scope!.colors;
  }

  static Color? _hex(String? value) {
    final digits = value?.replaceFirst('#', '') ?? '';
    final rgb = digits.length == 6 ? int.tryParse(digits, radix: 16) : null;
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }
}

/// Hands [colors] to the pieces of a page.
class SupportColorsScope extends InheritedWidget {
  /// Creates the scope.
  const SupportColorsScope({
    super.key,
    required this.colors,
    required super.child,
  });

  /// The page's colours.
  final SupportColors colors;

  @override
  bool updateShouldNotify(SupportColorsScope oldWidget) =>
      !identical(colors, oldWidget.colors);
}
