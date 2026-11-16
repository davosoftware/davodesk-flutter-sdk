import 'package:flutter/widgets.dart';

/// A new line in the chat: it fades in and rises 8 px over 180 ms, once (app feedback
/// spec §8). The page wraps only what arrives after it first showed, and nothing when
/// the phone asks for less animation.
class SlideIn extends StatefulWidget {
  /// Slides [child] in.
  const SlideIn({super.key, required this.child});

  /// The line.
  final Widget child;

  @override
  State<SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<SlideIn> with SingleTickerProviderStateMixin {
  late final _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  late final _eased = CurvedAnimation(parent: _arrival, curve: Curves.easeOut);

  @override
  void dispose() {
    _eased.dispose();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _eased,
    // A screen reader hears the line at once, not when the fade is done.
    alwaysIncludeSemantics: true,
    child: AnimatedBuilder(
      animation: _eased,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - _eased.value)),
        child: child,
      ),
      child: widget.child,
    ),
  );
}
