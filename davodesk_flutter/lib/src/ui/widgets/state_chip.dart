import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A ticket's state as the customer reads it, as the web widget's `ticket-state.ts`
/// says: Reply when the team waits for them, Solved, Closed (final), and Open for the
/// rest, including a state the SDK doesn't know.
class StateChip extends StatelessWidget {
  /// Creates the chip for a ticket's [status], followed by its [reference] when given.
  const StateChip({super.key, required this.status, this.reference});

  /// The API's status, such as `pending`.
  final String status;

  /// The ticket's reference, such as `#9BBC55`.
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final (label, color, background) = switch (status) {
      'pending' => ('Reply', colors.warn, colors.warnSoft),
      'resolved' => ('Solved', colors.ok, colors.okSoft),
      'closed' => ('Closed', colors.ink2, colors.rule),
      _ => ('Open', colors.accentInk, colors.accentSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reference == null ? label : '$label · $reference',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
