import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// "Powered by DavoDesk", small, with DavoDesk's mark.
class PoweredBy extends StatelessWidget {
  /// Creates the line.
  const PoweredBy({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/davodesk_logo.png',
          package: 'davodesk_flutter',
          width: 14,
          height: 14,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Powered by DavoDesk',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.ink3, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
