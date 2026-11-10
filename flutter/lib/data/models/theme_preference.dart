import 'package:flutter/material.dart';

/// How the app picks its brightness.
///
/// Default is [system]: a new install follows the phone, so a user in light
/// mode gets a light app on first launch instead of a black screen they did not
/// ask for. An explicit choice always wins and is stored on the device.
enum ThemePreference {
  system,
  light,
  dark;

  String get label => switch (this) {
        ThemePreference.system => 'Device',
        ThemePreference.light => 'Light',
        ThemePreference.dark => 'Dark',
      };

  ThemeMode get mode => switch (this) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  static ThemePreference fromStorage(String? value) =>
      ThemePreference.values.firstWhere(
        (p) => p.name == value,
        orElse: () => ThemePreference.system,
      );
}
