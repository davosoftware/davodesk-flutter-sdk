import 'package:cupertino_ui/cupertino_ui.dart'
    show DefaultCupertinoLocalizations;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Wraps an SDK page in its own `material_ui` theme and localizations (and
/// `cupertino_ui`'s, which its iOS text toolbar reads), so it works inside an app on
/// either Material, or on none.
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
      DefaultCupertinoLocalizations.delegate,
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

ThemeData _themeOf(SupportColors colors) {
  // Square corners reach the buttons and sheets too; rounded keeps their own.
  final square = colors.corners == DavoDeskCorners.square;
  const squareShape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(),
  );
  return ThemeData(
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
      shape: RoundedRectangleBorder(borderRadius: colors.corner(16)),
    ),
    dividerTheme: DividerThemeData(color: colors.rule, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: square ? const ButtonStyle(shape: squareShape) : null,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: square ? const ButtonStyle(shape: squareShape) : null,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: square ? const ButtonStyle(shape: squareShape) : null,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accentInk,
        shape: square ? const RoundedRectangleBorder() : null,
      ),
    ),
    bottomSheetTheme: square
        ? const BottomSheetThemeData(shape: RoundedRectangleBorder())
        : null,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

// A sheet and the text toolbar open in the app's overlay, outside the page's shell: in an
// app on Flutter's own Material, the overlay has no `material_ui` or `cupertino_ui`
// words, so they bring the shell along (app feedback spec §7).

/// Opens a modal sheet from an SDK page, its frame in the page's words and look too.
Future<T?> showSupportSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context);
  final words = MaterialLocalizations.of(context);
  return navigator.push(
    _SupportSheetRoute<T>(
      colors: SupportColors.of(context),
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: false,
      barrierLabel: words.scrimLabel,
      barrierOnTapHint: words.scrimOnTapHint(words.bottomSheetLabel),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    ),
  );
}

class _SupportSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _SupportSheetRoute({
    required this.colors,
    required super.builder,
    super.capturedThemes,
    required super.isScrollControlled,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
  });

  final SupportColors colors;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => SupportShell(
    colors: colors,
    child: super.buildPage(context, animation, secondaryAnimation),
  );
}

/// The text toolbar for a field on the SDK [page], in the page's words.
EditableTextContextMenuBuilder supportContextMenu(BuildContext page) {
  final colors = SupportColors.of(page);
  return (context, editable) => SupportShell(
    colors: colors,
    child: AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editable,
    ),
  );
}
