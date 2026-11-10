import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The brand's square logo on a white tile, or its initial when there is none or it
/// fails to load.
class BrandTile extends StatelessWidget {
  /// Creates the tile for [name], showing [logoUrl] when it loads.
  const BrandTile({
    super.key,
    required this.logoUrl,
    required this.name,
    this.size = 40,
  });

  /// The square logo's address.
  final String? logoUrl;

  /// The brand's name, for the initial and screen readers.
  final String name;

  /// The tile's side.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final trimmed = name.trim();
    final initial = Center(
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(
          color: colors.accent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = logoUrl;
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: colors.corner(size * 0.28),
          border: Border.all(color: colors.rule),
        ),
        child: ExcludeSemantics(
          child: url == null
              ? initial
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => initial,
                ),
        ),
      ),
    );
  }
}
