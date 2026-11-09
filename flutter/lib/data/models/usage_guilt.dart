/// How much the user actually uses a subscription.
///
/// This is the only input to the ghost calculation, and it is deliberately
/// explicit: the app never guesses usage from app-open telemetry.
enum UsageGuilt {
  dailyDriver,
  barelyTouch;

  /// Label shown in the Quick Add pills and the detail screen.
  String get label => switch (this) {
        UsageGuilt.dailyDriver => 'Daily Driver',
        UsageGuilt.barelyTouch => 'Barely Touch It',
      };

  /// Short flag printed on a subscription row.
  String get shortFlag => switch (this) {
        UsageGuilt.dailyDriver => 'DAILY USE',
        UsageGuilt.barelyTouch => 'GHOST',
      };

  bool get isGhost => this == UsageGuilt.barelyTouch;

  static UsageGuilt fromStorage(String value) => UsageGuilt.values.firstWhere(
        (g) => g.name == value,
        orElse: () => UsageGuilt.dailyDriver,
      );
}
