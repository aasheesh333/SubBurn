/// Presentation-only formatting helpers. Kept out of widgets so they can be
/// unit tested without a pump.
library;

/// `14h 22m` / `1d 11h` / `2m` — the countdown copy used on renewal cards.
String formatCountdown(Duration remaining) {
  if (remaining.isNegative) return 'now';
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;

  if (days >= 1) {
    return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  }
  if (hours >= 1) {
    return minutes > 0 ? '${hours}h ${minutes.toString().padLeft(2, '0')}m' : '${hours}h';
  }
  return '${minutes}m';
}

/// `14h 22m left`
String formatCountdownLeft(Duration remaining) =>
    remaining.isNegative ? 'renews now' : '${formatCountdown(remaining)} left';

/// `today` / `tomorrow` / `Fri 14 Nov`
String formatRenewalDay(DateTime date, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'tomorrow';
  return _weekday(date);
}

String formatChargeDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

String _weekday(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

/// `since Oct ’25`
String formatSince(DateTime start) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final year = (start.year % 100).toString().padLeft(2, '0');
  return 'since ${months[start.month - 1]} ’$year';
}

/// Money without a symbol, for text fields.
String formatPlainAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toStringAsFixed(2);
}

/// Parses `1,660`, `1660`, `$20` into 1660 / 20. Returns null when unusable.
double? parseAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return value;
}
