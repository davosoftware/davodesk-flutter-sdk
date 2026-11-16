import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// What just happened, in a tinted box a screen reader reads as it shows: green, or
/// amber when it went [wrong].
class StatusBanner extends StatelessWidget {
  /// Creates the banner.
  const StatusBanner(this.text, {super.key, this.wrong = false});

  /// What happened.
  final String text;

  /// Whether it went wrong.
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: wrong ? colors.warnSoft : colors.okSoft,
          borderRadius: colors.corner(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: wrong ? colors.warn : colors.ok,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
