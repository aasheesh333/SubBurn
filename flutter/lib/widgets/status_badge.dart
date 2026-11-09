import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

enum BadgeTone { neutral, safe, warn, danger }

/// Small mono pill. The only element in the app allowed to animate: the
/// renewal warning pulses so a scroll-past still registers as urgent.
class StatusBadge extends StatefulWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = BadgeTone.neutral,
    this.leadingDot = false,
    this.pulse = false,
  });

  final String label;
  final BadgeTone tone;
  final bool leadingDot;

  /// Enables the 2.4 s breathing animation (renewal < 3 days only).
  final bool pulse;

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SbMotion.pulse,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({Color fg, Color bg, Color border}) get _palette => switch (widget.tone) {
        BadgeTone.safe => (
            fg: const Color(0xFF34D399),
            bg: SbColors.safe.withValues(alpha: 0.10),
            border: SbColors.safe.withValues(alpha: 0.28),
          ),
        BadgeTone.warn => (
            fg: const Color(0xFFFBBF24),
            bg: SbColors.warn.withValues(alpha: 0.11),
            border: SbColors.warn.withValues(alpha: 0.30),
          ),
        BadgeTone.danger => (
            fg: const Color(0xFFF87171),
            bg: SbColors.danger.withValues(alpha: 0.10),
            border: SbColors.danger.withValues(alpha: 0.26),
          ),
        BadgeTone.neutral => (
            fg: SbColors.textSecondary,
            bg: const Color(0xFF0C0C0F),
            border: SbColors.border,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final p = _palette;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = widget.pulse ? Curves.easeInOut.transform(_c.value) : 0.0;
        return Container(
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.pulse
                  ? Color.lerp(p.border, p.border.withValues(alpha: 0.55), t)!
                  : p.border,
            ),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leadingDot) ...[
            _Dot(
              color: p.fg,
              pulse: widget.pulse,
              progress: _c,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            widget.label,
            style: SbType.micro.copyWith(color: p.fg, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.pulse, required this.progress});

  final Color color;
  final bool pulse;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = pulse ? Curves.easeOut.transform(progress.value) : 0.0;
        return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: pulse ? 0.55 * (1 - t) : 0.16),
                blurRadius: 0,
                spreadRadius: pulse ? 5 * t : 3,
              ),
            ],
          ),
        );
      },
    );
  }
}
