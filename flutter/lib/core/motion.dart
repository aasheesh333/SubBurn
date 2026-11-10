import 'dart:async';

import 'package:flutter/material.dart';

/// Motion tokens.
///
/// The original design only declared one animation (the renewal pulse), which is
/// why the app felt static next to the Figma prototype: screens cut instead of
/// moving, numbers snapped into place, and the receipt appeared with no
/// transition. These durations are the ones used everywhere now.
///
/// Everything is intentionally short. This is a money app opened for two
/// seconds at a time; animations earn their place by explaining a change, not by
/// showing off.
abstract final class SbMotion {
  /// Renewal badge breathing.
  static const pulse = Duration(milliseconds: 2400);

  /// Fast state change (theme switch, segment selection).
  static const quick = Duration(milliseconds: 180);

  /// Press feedback on buttons and tappable cards.
  static const press = Duration(milliseconds: 110);

  /// Route push / pop.
  static const route = Duration(milliseconds: 240);

  /// Bottom-sheet content settling.
  static const sheet = Duration(milliseconds: 260);

  /// A value changing in place (split bar, counters).
  static const value = Duration(milliseconds: 520);

  /// Per-item delay in a list entrance.
  static const stagger = Duration(milliseconds: 32);

  /// Longest list entrance is capped so a 40-row list does not crawl.
  static const maxStaggerIndex = 5;

  static const curve = Curves.easeOutCubic;
  static const curveIn = Curves.easeInCubic;

  /// True when the OS asks for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Scales a duration to zero under reduce-motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// A fade + small upward slide, used for every pushed route.
///
/// The default Material route on Android is a horizontal slide that belongs to
/// a tabbed app; SubBurn is a stack of detail views, so a short vertical lift
/// reads better and matches the prototype.
class SbPageRoute<T> extends PageRouteBuilder<T> {
  SbPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: SbMotion.route,
          reverseTransitionDuration: SbMotion.route,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            if (SbMotion.reduced(context)) return child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: SbMotion.curve,
              reverseCurve: SbMotion.curveIn,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Fades its child in once, with an optional delay. Used for list rows and
/// cards so a screen assembles instead of appearing fully formed.
class SbEntrance extends StatefulWidget {
  const SbEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 10,
  });

  final Widget child;

  /// Position in a list; the delay is `index * stagger`, capped.
  final int index;

  /// Vertical travel in logical pixels.
  final double offset;

  @override
  State<SbEntrance> createState() => _SbEntranceState();
}

class _SbEntranceState extends State<SbEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SbMotion.route,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.index.clamp(0, SbMotion.maxStaggerIndex) *
        SbMotion.stagger.inMilliseconds;
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SbMotion.reduced(context)) {
      _timer?.cancel();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(parent: _c, curve: SbMotion.curve);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animates a number from its previous value to the new one.
///
/// The hero total is the product; snapping it from ₹4,850 to ₹6,510 hides the
/// change. This rolls it over ~0.5 s, and jumps immediately under reduce-motion.
class SbAnimatedNumber extends StatefulWidget {
  const SbAnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.duration,
  });

  final num value;
  final Widget Function(BuildContext context, num value) builder;
  final Duration? duration;

  @override
  State<SbAnimatedNumber> createState() => _SbAnimatedNumberState();
}

class _SbAnimatedNumberState extends State<SbAnimatedNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? SbMotion.value,
  );
  late num _from = widget.value;
  late num _to = widget.value;

  @override
  void didUpdateWidget(covariant SbAnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _from = _current;
    _to = widget.value;
    if (SbMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  num get _current {
    final t = Curves.easeOutCubic.transform(_c.value);
    return _from + (_to - _from) * t;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, _current),
    );
  }
}
