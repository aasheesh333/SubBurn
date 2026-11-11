/// Presentation-only formatting helpers. Kept out of widgets so they can be
/// unit tested without a pump.
library;

import 'package:flutter/material.dart';

import '../clock.dart';

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
    return minutes > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${hours}h';
  }
  return '${minutes}m';
}

/// `14h 22m left`
String formatCountdownLeft(Duration remaining) =>
    remaining.isNegative ? 'renews now' : '${formatCountdown(remaining)} left';

/// `today` / `tomorrow` / `Fri 14 Nov`
String formatRenewalDay(DateTime date, {DateTime? now}) {
  final clock = now ?? SbClock.now();
  // Calendar-day difference via UTC: `target.difference(today).inDays` on
  // local midnights returns 23h days across a DST spring-forward, which made
  // tomorrow's renewal read "today" for a whole week.
  final today = DateTime.utc(clock.year, clock.month, clock.day);
  final target = DateTime.utc(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'tomorrow';
  return _weekday(date);
}

/// `Wed 15 Nov`, or `Wed 15 Nov '27` when the year is not the current one —
/// the pickers span 2000 → now+3y, so a bare day+month is ambiguous.
String formatChargeDate(DateTime date, {DateTime? now}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final base =
      '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  final clock = now ?? SbClock.now();
  if (date.year == clock.year) return base;
  return "$base ’${(date.year % 100).toString().padLeft(2, '0')}";
}

String _weekday(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

/// Actual Mon–Fri days in [month]'s calendar month.
///
/// Used by the receipt's per-workday figure when it is generated live. An
/// archived receipt pins 22 so its printed number never changes.
/// Iterated by day index, not by adding 24h Durations: in a spring-forward
/// month a 23h day makes the old iterator visit one calendar day twice.
int workdaysInMonth(DateTime month) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  var count = 0;
  for (var i = 1; i <= daysInMonth; i++) {
    if (DateTime(month.year, month.month, i).weekday <= DateTime.friday) {
      count++;
    }
  }
  return count;
}

/// `since Oct ’25`
String formatSince(DateTime start) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final year = (start.year % 100).toString().padLeft(2, '0');
  return 'since ${months[start.month - 1]} ’$year';
}

/// 1–2 character monogram from a product name, grapheme-safe.
///
/// `String[0]` returns a UTF-16 code unit, which cut emoji names into lone
/// surrogates that render as □; `characters.first` takes the whole grapheme.
String monogramFor(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((w) => w.isEmpty ? '' : w.characters.first)
    .join()
    .toUpperCase();

/// Money without a symbol, for text fields.
String formatPlainAmount(num amount) {
  // Guard non-finite input: `Infinity.round()` throws, and a stored Infinity
  // (reachable from an unbounded price field) used to crash the edit sheet's
  // initState. Validation at entry keeps this from ever being hit normally.
  if (!amount.isFinite) return '0';
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toStringAsFixed(2);
}

/// Parses `1,660`, `1660`, `$20`, `9,99` into 1660 / 20 / 9.99.
/// Returns null when unusable.
///
/// A single comma is locale-ambiguous: `1,660` groups thousands while `9,99`
/// is a decimal. The digits after the comma decide — exactly 3 reads as a
/// grouping separator, 1–2 as a decimal point. The old parser stripped every
/// comma, silently turning a comma-decimal `9,99` into 999.
double? parseAmount(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (cleaned.isEmpty) return null;

  if (!cleaned.contains('.')) {
    final commas = ','.allMatches(cleaned).length;
    if (commas == 1) {
      final afterComma = cleaned.split(',')[1];
      if (afterComma.length == 1 || afterComma.length == 2) {
        cleaned = cleaned.replaceFirst(',', '.');
      } else if (afterComma.length != 3) {
        return null; // neither a valid grouping nor a decimal
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (commas > 1) {
      cleaned = cleaned.replaceAll(',', ''); // 1,234,567-style grouping
    }
  } else {
    cleaned = cleaned.replaceAll(',', ''); // 1,660.50-style grouping
  }

  if ('.'.allMatches(cleaned).length > 1) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0 || !value.isFinite) return null;
  return value;
}
