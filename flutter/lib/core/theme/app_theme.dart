import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_tokens.dart';

/// Material 3 theme. Dark only, by design.
///
/// Typography is authored through `google_fonts`, but runtime fetching is
/// disabled in `main()` — matching families are bundled under
/// `assets/google_fonts` using Google Fonts' asset naming convention, so first
/// paint is instant and the app works offline. The bundled JetBrains Mono
/// carries a transplanted ₹ glyph (U+20B9).
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);

    TextStyle ui(
      TextStyle? style, {
      double? size,
      FontWeight? weight,
      double? height,
      double? spacing,
      Color? color,
    }) {
      return GoogleFonts.plusJakartaSans(
        textStyle: style,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );
    }

    TextStyle mono(
      TextStyle? style, {
      double? size,
      FontWeight? weight,
      double? height,
      double? spacing,
      Color? color,
    }) {
      return GoogleFonts.jetBrainsMono(
        textStyle: style,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );
    }

    const scheme = ColorScheme.dark(
      primary: SbColors.accent,
      onPrimary: Color(0xFF180900),
      secondary: SbColors.accentAlt,
      onSecondary: Color(0xFF180900),
      surface: SbColors.surface,
      onSurface: SbColors.text,
      surfaceContainerHighest: SbColors.surfaceHi,
      error: SbColors.danger,
      onError: SbColors.text,
      outline: SbColors.border,
      outlineVariant: SbColors.borderHi,
    );

    final textTheme = TextTheme(
      displayLarge: mono(
        base.textTheme.displayLarge,
        size: 58,
        weight: FontWeight.w600,
        height: 1,
        spacing: -0.055 * 58,
        color: SbColors.text,
      ),
      headlineLarge: ui(
        base.textTheme.headlineLarge,
        size: 25,
        weight: FontWeight.w800,
        height: 26 / 25,
        spacing: -0.035 * 25,
        color: SbColors.text,
      ),
      headlineMedium: ui(
        base.textTheme.headlineMedium,
        size: 22,
        weight: FontWeight.w800,
        height: 24 / 22,
        spacing: -0.035 * 22,
        color: SbColors.text,
      ),
      headlineSmall: ui(
        base.textTheme.headlineSmall,
        size: 16,
        weight: FontWeight.w800,
        height: 20 / 16,
        spacing: -0.03 * 16,
        color: SbColors.text,
      ),
      titleMedium: ui(
        base.textTheme.titleMedium,
        size: 13,
        weight: FontWeight.w700,
        height: 16 / 13,
        spacing: -0.015 * 13,
        color: SbColors.text,
      ),
      bodyLarge: ui(
        base.textTheme.bodyLarge,
        size: 14,
        color: SbColors.text,
      ),
      bodyMedium: ui(
        base.textTheme.bodyMedium,
        size: 12,
        weight: FontWeight.w500,
        height: 16 / 12,
        color: SbColors.textSecondary,
      ),
      bodySmall: ui(
        base.textTheme.bodySmall,
        size: 10,
        height: 14 / 10,
        color: SbColors.textMuted,
      ),
      labelSmall: ui(
        base.textTheme.labelSmall,
        size: 10,
        weight: FontWeight.w700,
        spacing: 0.115 * 10,
        color: SbColors.textMuted,
      ),
      labelLarge: ui(
        base.textTheme.labelLarge,
        size: 13,
        weight: FontWeight.w700,
        color: SbColors.text,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: SbColors.bg,
      canvasColor: SbColors.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x14FF4500),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: SbColors.border,
        thickness: SbSize.hairline,
        space: SbSize.hairline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SbColors.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: SbColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SbColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: SbColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SbRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SbColors.surfaceHi,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: SbColors.text,
        ),
        actionTextColor: SbColors.accentWarm,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SbRadius.inner),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SbColors.surfaceHi,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: SbColors.textMuted,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SbSpace.x4,
          vertical: SbSpace.x3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SbRadius.button),
          borderSide: const BorderSide(color: SbColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SbRadius.button),
          borderSide: const BorderSide(color: SbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SbRadius.button),
          borderSide: const BorderSide(color: SbColors.accent, width: 1.2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SbColors.accent
              : SbColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SbColors.accent.withValues(alpha: 0.32)
              : SbColors.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(SbColors.borderHi),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SbColors.accent,
        linearTrackColor: SbColors.border,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SbColors.accentWarm,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
