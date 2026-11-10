import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The brand's wordmark, kept in its own shape, or the brand's name in bold when there
/// is none or it fails to load.
class HeaderLogo extends StatelessWidget {
  /// Creates the logo for [name], showing [url] when it loads.
  const HeaderLogo({
    super.key,
    required this.url,
    required this.name,
    this.height = 28,
    this.color,
  });

  /// The wordmark's address.
  final String? url;

  /// The brand's name.
  final String name;

  /// The wordmark's height.
  final double height;

  /// The name's colour; the page's ink by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final name = Text(
      this.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? colors.ink,
        fontFamily: colors.headingFontFamily,
        fontSize: height * 0.72,
        fontWeight: FontWeight.w800,
      ),
    );
    final url = this.url;
    if (url == null) return name;
    return Semantics(
      label: this.name,
      image: true,
      child: ExcludeSemantics(
        child: Image.network(
          url,
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, _, _) => name,
        ),
      ),
    );
  }
}
