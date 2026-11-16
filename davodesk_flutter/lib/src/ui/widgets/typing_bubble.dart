import 'package:material_ui/material_ui.dart';

import '../features/conversation/conversation_view_model.dart';
import '../theme.dart';
import 'brand_tile.dart';

/// Three dots while someone writes an answer (app feedback spec §2): DavoDesk AI under
/// its run head, a person on the team under their name. The dots hold still when the
/// phone asks for less animation.
class TypingBubble extends StatefulWidget {
  /// Creates the bubble for [item].
  const TypingBubble({super.key, required this.item});

  /// Who is typing.
  final TypingItem item;

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _dots.stop();
    } else if (!_dots.isAnimating) {
      _dots.repeat();
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final dark = colors.brightness == Brightness.dark;
    final item = widget.item;
    final still = MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        label: '${item.name} is typing',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    if (item.ai)
                      BrandTile(
                        logoUrl: item.logoUrl,
                        name: item.brand ?? item.name,
                        size: 18,
                      ),
                    Text(
                      item.name,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    colors.paper,
                    colors.ink,
                    dark ? 0.08 : 0.05,
                  ),
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: colors.bend(4),
                    topEnd: colors.bend(14),
                    bottomStart: colors.bend(14),
                    bottomEnd: colors.bend(14),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _dots,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      for (var index = 0; index < 3; index++)
                        Opacity(
                          opacity: still ? 0.6 : _brightness(index),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.ink3,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Each dot brightens in turn: 0.35, up to 1 and back, a little after the one before.
  double _brightness(int index) {
    final phase = (_dots.value - index * 0.15) % 1.0;
    if (phase < 0.3) return 0.35 + phase / 0.3 * 0.65;
    if (phase < 0.6) return 1 - (phase - 0.3) / 0.3 * 0.65;
    return 0.35;
  }
}
