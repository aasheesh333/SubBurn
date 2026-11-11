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
  static ThemeData get dark => _build(SbPalette.dark);

  static ThemeData get light => _build(SbPalette.light);

  /// One builder for both brightnesses. Every colour comes from [p], so a token
  /// can only drift if it is missing from the palette.
  static ThemeData _build(SbPalette p) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
    );

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

    final scheme = ColorScheme(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accentAlt,
      onSecondary: p.onAccent,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.surfaceHi,
      error: p.danger,
      onError: p.isDark ? p.text : const Color(0xFFFFFFFF),
      outline: p.border,
      outlineVariant: p.borderHi,
    );

    final textTheme = TextTheme(
      displayLarge: mono(
        base.textTheme.displayLarge,
        size: 58,
        weight: FontWeight.w600,
        height: 1,
        spacing: -0.055 * 58,
        color: p.text,
      ),
      headlineLarge: ui(
        base.textTheme.headlineLarge,
        size: 25,
        weight: FontWeight.w800,
        height: 26 / 25,
        spacing: -0.035 * 25,
        color: p.text,
      ),
      headlineMedium: ui(
        base.textTheme.headlineMedium,
        size: 22,
        weight: FontWeight.w800,
        height: 24 / 22,
        spacing: -0.035 * 22,
        color: p.text,
      ),
      headlineSmall: ui(
        base.textTheme.headlineSmall,
        size: 16,
        weight: FontWeight.w800,
        height: 20 / 16,
        spacing: -0.03 * 16,
        color: p.text,
      ),
      titleMedium: ui(
        base.textTheme.titleMedium,
        size: 13,
        weight: FontWeight.w700,
        height: 16 / 13,
        spacing: -0.015 * 13,
        color: p.text,
      ),
      bodyLarge: ui(
        base.textTheme.bodyLarge,
        size: 14,
        color: p.text,
      ),
      bodyMedium: ui(
        base.textTheme.bodyMedium,
        size: 12,
        weight: FontWeight.w500,
        height: 16 / 12,
        color: p.textSecondary,
      ),
      bodySmall: ui(
        base.textTheme.bodySmall,
        size: 10,
        height: 14 / 10,
        color: p.textMuted,
      ),
      labelSmall: ui(
        base.textTheme.labelSmall,
        size: 10,
        weight: FontWeight.w700,
        spacing: 0.115 * 10,
        color: p.textMuted,
      ),
      labelLarge: ui(
        base.textTheme.labelLarge,
        size: 13,
        weight: FontWeight.w700,
        color: p.text,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      extensions: <ThemeExtension<dynamic>>[p],
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x14FF4500),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: SbSize.hairline,
        space: SbSize.hairline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.text,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SbRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHi,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: p.text,
        ),
        actionTextColor: p.accentWarm,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SbRadius.inner),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceHi,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: p.textMuted,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SbSpace.x4,
          vertical: SbSpace.x3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SbRadius.button),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SbRadius.button),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SbRadius.button),
          borderSide: BorderSide(color: p.accent, width: 1.2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accent : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent.withValues(alpha: 0.32)
              : p.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.borderHi),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.border,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentWarm,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
