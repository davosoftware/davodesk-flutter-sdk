import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme, ThemeData;

import '../domain/models.dart';

// The channel's look reads corners too, so their type lives with the API's shapes.
export '../domain/models.dart' show DavoDeskCorners;

/// What DavoDesk's screens use when neither the app nor the channel sets an accent.
const defaultAccent = Color(0xFF1D4ED8);

/// How the support screens look, when the app wants a say.
///
/// Without it, the accent is the channel's, light or dark follows the app (an app on
/// `material_ui`) or the phone, the font is the app's or the platform's, and the other
/// colours are DavoDesk's. [light] and [dark] set the screen colours for each;
/// [headingFontFamily] sets the titles' font (the body font without it); [corners]
/// makes the screens square.
class const DavoDeskTheme({
  final Color? accent,
  final Brightness? brightness,
  final String? fontFamily,
  final String? headingFontFamily,
  final DavoDeskColors? light,
  final DavoDeskColors? dark,
  final DavoDeskCorners corners = DavoDeskCorners.rounded,
}) {
  /// Creates a [DavoDeskTheme].
  this;
}

/// The screen colours for light or for dark; a colour left out keeps DavoDesk's.
///
/// [background] paints pages and cards; [surface], a shade darker, paints text fields
/// and Home behind its cards; [text] is the main text, and the quieter text and the
/// team's chat bubbles follow it; [border] draws lines and edges. [accent] beats
/// [DavoDeskTheme.accent] in this mode.
class const DavoDeskColors({
  final Color? accent,
  final Color? background,
  final Color? surface,
  final Color? text,
  final Color? border,
}) {
  /// Creates a [DavoDeskColors].
  this;
}

/// The contact form's words that belong to the app: [note], the line in the highlighted
/// card (no card without one), and an optional [extraField].
class const DavoDeskContactForm({
  final String? note,
  final DavoDeskFormField? extraField,
}) {
  /// Creates a [DavoDeskContactForm].
  this;
}

/// An extra field on the contact form, such as an order number; its value goes first in
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
  required final Color accentInk,
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
  final String? headingFontFamily,
  final DavoDeskCorners corners = DavoDeskCorners.rounded,
}) {
  /// Creates the colours.
  this;

  /// [radius], or none when the app wants square corners.
  BorderRadius corner(double radius) =>
      BorderRadius.circular(corners == DavoDeskCorners.square ? 0 : radius);

  /// One corner of [radius], or none when the app wants square corners.
  Radius bend(double radius) =>
      Radius.circular(corners == DavoDeskCorners.square ? 0 : radius);

  /// The mockup's colours for [brightness], around [accent], with the app's [own] in
  /// place of any it sets.
  factory from({
    required Color accent,
    required Brightness brightness,
    String? fontFamily,
    String? headingFontFamily,
    DavoDeskColors? own,
    DavoDeskCorners corners = DavoDeskCorners.rounded,
  }) {
    final dark = brightness == Brightness.dark;
    final paper =
        own?.background ??
        (dark ? const Color(0xFF14171D) : const Color(0xFFFFFFFF));
    final text = own?.text;
    final accentSoft = Color.lerp(paper, accent, dark ? 0.3 : 0.1)!;
    return SupportColors(
      brightness: brightness,
      accent: accent,
      accentSoft: accentSoft,
      accentInk: _readable(accent, accentSoft, dark: dark),
      onAccent: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF0F172A),
      ink: text ?? (dark ? const Color(0xFFE8EBF2) : const Color(0xFF0F172A)),
      ink2: text != null
          ? Color.lerp(text, paper, 0.25)!
          : (dark ? const Color(0xFFA4ADBF) : const Color(0xFF475569)),
      ink3: text != null
          ? Color.lerp(text, paper, 0.55)!
          : (dark ? const Color(0xFF6B7487) : const Color(0xFF94A3B8)),
      rule:
          own?.border ??
          (dark ? const Color(0xFF252A35) : const Color(0xFFE5E7EB)),
      paper: paper,
      shelf:
          own?.surface ??
          (dark ? const Color(0xFF0B0D12) : const Color(0xFFF5F6F8)),
      ok: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      okSoft: dark ? const Color(0xFF10301D) : const Color(0xFFDCFCE7),
      warn: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      warnSoft: dark ? const Color(0xFF3A2A0C) : const Color(0xFFFEF3C7),
      fontFamily: fontFamily,
      headingFontFamily: headingFontFamily ?? fontFamily,
      corners: corners,
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
    final brightness =
        theme?.brightness ??
        appBrightness ??
        MediaQuery.platformBrightnessOf(context);
    final own = brightness == Brightness.dark ? theme?.dark : theme?.light;
    return SupportColors.from(
      accent:
          own?.accent ??
          theme?.accent ??
          _hex(config?.appearance?.accentColor) ??
          defaultAccent,
      brightness: brightness,
      own: own,
      fontFamily:
          theme?.fontFamily ??
          (appBrightness == null
              ? null
              : Theme.of(context).textTheme.bodyMedium?.fontFamily),
      headingFontFamily: theme?.headingFontFamily,
      corners: theme?.corners ?? DavoDeskCorners.rounded,
    );
  }

  /// The colours of the page around [context].
  static SupportColors of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SupportColorsScope>();
    assert(scope != null, 'An SDK piece is outside a SupportShell.');
    return scope!.colors;
  }

  /// [accent] where it is text, an icon or a dot: made darker (light) or lighter (dark)
  /// until it reads at 4.5:1 on [on]; fills keep the accent itself.
  static Color _readable(Color accent, Color on, {required bool dark}) {
    final toward = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    for (var step = 0; step <= 20; step++) {
      final color = Color.lerp(accent, toward, step / 20)!;
      if (_contrast(color, on) >= 4.5) return color;
    }
    return toward;
  }

  static double _contrast(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
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
