import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

/// The base surface used by every card and row: 1 px hairline, inner top
/// highlight (that's how a dark UI reads depth), optional brand tint.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SbSpace.x3),
    this.radius = SbRadius.inner,
    this.tint,
    this.dashed = false,
    this.onTap,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool dashed;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            if (tint != null) tint!.withValues(alpha: 0.07) else context.sb.surfaceHi,
            context.sb.surface,
          ],
        ),
        border: Border.all(
          color: tint?.withValues(alpha: 0.22) ?? context.sb.border,
          width: SbSize.hairline,
        ),
        boxShadow: const [SbShadow.cardInner],
      ),
      child: child,
    );

    // Dashed outline marks a ghost subscription — it is deliberately a
    // different shape language, not just a different colour.
    final outlined = dashed
        ? CustomPaint(
            painter: _DashedBorderPainter(
              color: context.sb.border.withValues(alpha: 0.9),
              radius: radius,
            ),
            child: body,
          )
        : body;

    if (onTap == null) return outlined;

    // Tappable surfaces press in slightly. Without it a card that does open a
    // detail view felt identical to the static rows beside it.
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: _PressScale(child: outlined),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = SbSize.hairline;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    const dash = 4.0;
    const gap = 4.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}


/// Subtle press-in for tappable surfaces. Disabled when the OS asks for less
/// motion, and never on hover-less desktop where there is no tap feedback need.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final animate = !SbMotion.reduced(context);
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: animate ? SbMotion.press : Duration.zero,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
