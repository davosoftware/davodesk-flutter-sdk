import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// What a page shows when what it needs couldn't be read: "Something went wrong here."
/// and Start again, which reads it again.
class Recover extends StatelessWidget {
  /// Creates the panel; [onRetry] runs on Start again.
  const Recover({super.key, required this.onRetry});

  /// Reads the page's data again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Something went wrong here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.ink2, fontSize: 15),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Start again')),
        ],
      ),
    );
  }
}
