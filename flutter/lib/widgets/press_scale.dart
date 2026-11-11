import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

/// Subtle press-in for tap targets.
///
/// The app theme disables ink splash (`NoSplash.splashFactory`) as a design
/// choice, which left most controls — CTAs, header buttons, nav items, pills,
/// chips, date tiles — with zero press feedback. This is the shared
/// compensation: a 3 % scale-down while the pointer is down, disabled when the
/// OS asks for reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final animate = !SbMotion.reduced(context);
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: animate ? SbMotion.press : Duration.zero,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
