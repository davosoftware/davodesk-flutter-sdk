import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A page's top bar: back, and the page's title (with an optional [subtitle]).
class PageBar extends StatelessWidget {
  /// Creates the bar.
  const PageBar({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.centered = false,
  });

  /// The page's title, read as its heading.
  final String title;

  /// A line under the title.
  final String? subtitle;

  /// Goes back.
  final VoidCallback onBack;

  /// Whether the title sits in the middle.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final align = centered ? TextAlign.center : TextAlign.start;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Row(
          spacing: 6,
          children: [
            IconButton(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: colors.rule.withValues(alpha: 0.6),
                foregroundColor: colors.ink,
              ),
              icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Back'),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: centered
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Semantics(
                    headingLevel: 1,
                    child: Text(
                      title,
                      textAlign: align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontFamily: colors.headingFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (subtitle case final line?)
                    Text(
                      line,
                      textAlign: align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.ink2, fontSize: 12),
                    ),
                ],
              ),
            ),
            // Balances the back button, so a centred title is centred on the page.
            if (centered) const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
