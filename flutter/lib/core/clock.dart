import 'package:flutter/foundation.dart';

/// The app's only source of "now".
///
/// Everything time-dependent — renewal countdowns, the notice ring, overdue
/// rollover, lifetime spend — reads the clock through here instead of calling
/// `DateTime.now()` inline. That makes golden tests deterministic (they freeze
/// the clock) and makes the time logic unit-testable without sleeping.
abstract final class SbClock {
  static DateTime Function() _now = DateTime.now;

  static DateTime now() => _now();

  /// Pins the clock. Call from `setUp` and reset in `tearDown`.
  @visibleForTesting
  static void freeze(DateTime instant) {
    _now = () => instant;
  }

  @visibleForTesting
  static void reset() {
    _now = DateTime.now;
  }
}