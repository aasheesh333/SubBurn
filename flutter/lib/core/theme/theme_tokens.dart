/// SubBurn design tokens — the single source of truth for colour, spacing,
/// radius, typography and motion.
///
/// Mirrors `design-tokens.json` and the Figma local styles. Canvas is
/// 393 × 852 at a 16 px page inset on an 8 px grid, dark mode only.
///
/// Accessibility note: the brief's `#52525B` muted grey measures ~2.9:1 on
/// `#121216`, which fails WCAG AA for text. It stays available as
/// [SbColors.mutedDeco] for hairlines and decoration only; readable captions
/// use [SbColors.textMuted] (`#9A9AA4`, 5.6:1).
library;

import 'package:flutter/material.dart';

export '../motion.dart' show SbMotion;

/// Semantic palette. No widget in the app hard-codes a hex value.
abstract final class SbColors {
  // ── surfaces ──────────────────────────────────────────────────────────
  /// Rich obsidian canvas.
  static const bg = Color(0xFF09090B);

  /// Card / list-row surface.
  static const surface = Color(0xFF121216);

  /// Raised surface (sheet controls, chips).
  static const surfaceHi = Color(0xFF17171C);

  /// 1 px hairline.
  static const border = Color(0xFF27272A);

  /// Divider and inactive track.
  static const borderHi = Color(0xFF3F3F46);

  // ── brand ─────────────────────────────────────────────────────────────
  /// Electric burn orange — gradient start.
  static const accent = Color(0xFFFF4500);

  /// Gradient end.
  static const accentAlt = Color(0xFFFF8C00);

  /// Orange text on dark that still clears AA.
  static const accentWarm = Color(0xFFFFB27A);

  // ── semantic ──────────────────────────────────────────────────────────
  /// Active / daily driver.
  static const safe = Color(0xFF10B981);

  /// Renewal inside 72 h.
  static const warn = Color(0xFFF59E0B);

  /// Ghost spend / over budget / cancel.
  static const danger = Color(0xFFEF4444);

  // ── text ──────────────────────────────────────────────────────────────
  static const text = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);

  /// Captions — 5.6:1, WCAG AA at 9 px and up.
  static const textMuted = Color(0xFF9A9AA4);

  /// Brief-specified muted. Decoration only — never text.
  static const mutedDeco = Color(0xFF52525B);
}

/// Spacing scale. Every value is a multiple of 8; 4 px is the only half-step.
abstract final class SbSpace {
  static const x0 = 0.0;
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x7 = 32.0;
  static const x8 = 40.0;
  static const x9 = 48.0;

  /// Outer frame padding.
  static const page = x4;
}

abstract final class SbRadius {
  static const tile = 10.0;
  static const inner = 12.0;
  static const button = 14.0;
  static const composite = 18.0;
  static const hero = 24.0;
  static const sheet = 26.0;
  static const device = 46.0;
  static const pill = 999.0;
}

abstract final class SbSize {
  static const canvas = Size(393, 852);
  static const minTapTarget = 44.0;
  static const hairline = 1.0;

  /// The share card is authored at 360 × 640 and exported at 3×.
  static const shareCard = Size(360, 640);
  static const shareCardPixelRatio = 3.0;

  /// Renewing-soon window, in hours.
  static const renewingWindowHours = 72;
}

abstract final class SbFonts {
  /// UI family. Bundled as an asset in `assets/google_fonts`.
  static const ui = 'PlusJakartaSans';

  /// Numerals and money. Carries a transplanted ₹ glyph (U+20B9).
  static const mono = 'JetBrainsMono';
}

/// Type ramp. Mirrors the Figma text styles 1:1.
abstract final class SbType {
  static const display = TextStyle(
    fontFamily: SbFonts.mono,
    fontSize: 58,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.055 * 58,
    fontFeatures: [FontFeature.tabularFigures(), FontFeature.liningFigures()],
  );

  static const h1 = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 25,
    height: 26 / 25,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.035 * 25,
  );

  static const h2 = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 22,
    height: 24 / 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.035 * 22,
  );

  static const h3 = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.03 * 16,
  );

  static const section = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.015 * 13,
  );

  static const body = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w500,
  );

  static const label = TextStyle(
    fontFamily: SbFonts.ui,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.115 * 10,
  );

  static const micro = TextStyle(
    fontFamily: SbFonts.mono,
    fontSize: 9,
    height: 11 / 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.06 * 8,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const moneyLg = TextStyle(
    fontFamily: SbFonts.mono,
    fontSize: 34,
    height: 36 / 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.055 * 34,
    fontFeatures: [FontFeature.tabularFigures(), FontFeature.liningFigures()],
  );

  static const moneyMd = TextStyle(
    fontFamily: SbFonts.mono,
    fontSize: 16,
    height: 18 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.04 * 16,
    fontFeatures: [FontFeature.tabularFigures(), FontFeature.liningFigures()],
  );

  static const moneySm = TextStyle(
    fontFamily: SbFonts.mono,
    fontSize: 12,
    height: 14 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.03 * 12,
    fontFeatures: [FontFeature.tabularFigures(), FontFeature.liningFigures()],
  );
}

abstract final class SbGradients {
  static const burn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SbColors.accent, SbColors.accentAlt],
  );

  static const burnVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [SbColors.accentAlt, SbColors.accent],
  );

  /// Applied to the hero amount through a [ShaderMask].
  static const heroAmount = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFC9A0), Color(0xFFFF6A1A)],
    stops: [0.04, 0.46, 1.0],
  );

  static const heroGlow = RadialGradient(
    colors: [Color(0x57FF4500), Color(0x1AFF8C00), Color(0x00000000)],
    stops: [0.0, 0.45, 0.7],
  );
}

/// Elevation in a dark UI is an inner top highlight plus a coloured bloom —
/// never a grey drop shadow.
abstract final class SbShadow {
  static const cardInner = BoxShadow(
    color: Color(0x0BFFFFFF),
    offset: Offset(0, 1),
    blurRadius: 0,
  );

  static const heroGlow = BoxShadow(
    color: Color(0x8CFF4500),
    offset: Offset(0, 24),
    blurRadius: 46,
    spreadRadius: -26,
  );

  static const ctaGlow = BoxShadow(
    color: Color(0xF2FF4500),
    offset: Offset(0, 16),
    blurRadius: 34,
    spreadRadius: -12,
  );
}



/// Resolved colour set for one [Brightness].
///
/// `SbColors` holds the *dark* constants (kept because gradients, shadows and
/// tests reference them directly). Widgets must never read `SbColors` for
/// surfaces or text — they read `context.sb`, which resolves to this palette
/// from the active theme. That is what makes light mode possible without a
/// second copy of every widget.
@immutable
class SbPalette extends ThemeExtension<SbPalette> {
  const SbPalette({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.border,
    required this.borderHi,
    required this.accent,
    required this.accentAlt,
    required this.accentWarm,
    required this.safe,
    required this.warn,
    required this.danger,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.mutedDeco,
    required this.onAccent,
    required this.heroSurface,
    required this.heroBorder,
    required this.heroAmount,
    required this.segmentSurface,
    required this.segmentSelected,
    required this.cardShadow,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHi;
  final Color border;
  final Color borderHi;
  final Color accent;
  final Color accentAlt;
  final Color accentWarm;
  final Color safe;
  final Color warn;
  final Color danger;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color mutedDeco;

  /// Foreground on an accent-filled surface (button label, FAB glyph).
  final Color onAccent;

  /// Hero card background gradient stops.
  final List<Color> heroSurface;

  final Color heroBorder;

  /// Segmented control track and selected-segment fill.
  final Color segmentSurface;
  final List<Color> segmentSelected;

  /// Gradient applied to the hero amount.
  final Gradient heroAmount;

  final List<BoxShadow> cardShadow;
  final bool isDark;

  static const dark = SbPalette(
    bg: SbColors.bg,
    surface: SbColors.surface,
    surfaceHi: SbColors.surfaceHi,
    border: SbColors.border,
    borderHi: SbColors.borderHi,
    accent: SbColors.accent,
    accentAlt: SbColors.accentAlt,
    accentWarm: SbColors.accentWarm,
    safe: SbColors.safe,
    warn: SbColors.warn,
    danger: SbColors.danger,
    text: SbColors.text,
    textSecondary: SbColors.textSecondary,
    textMuted: SbColors.textMuted,
    mutedDeco: SbColors.mutedDeco,
    onAccent: Color(0xFF1A0800),
    // Figma paints HeroCard a solid #241B0C and adds a separate glow ellipse.
    heroSurface: [Color(0xFF241B0C), Color(0xFF241B0C), Color(0xFF241B0C)],
    heroBorder: Color(0xFF33271F),
    heroAmount: SbGradients.heroAmount,
    segmentSurface: Color(0xFF0B0B0E),
    segmentSelected: [Color(0xFF231A16), Color(0xFF1B1512)],
    cardShadow: [SbShadow.cardInner],
    isDark: true,
  );

  /// Light theme.
  ///
  /// Not a naive inversion: the accent stays electric, but text tones are
  /// re-picked so every caption still clears WCAG AA on white (the dark
  /// palette's muted grey measures 2.6:1 there), and the hero gradient starts
  /// at a mid orange instead of white, which would vanish on white.
  static const light = SbPalette(
    bg: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFF2F2F4),
    border: Color(0xFFE4E4E7),
    borderHi: Color(0xFFD4D4D8),
    accent: Color(0xFFE63E00),
    accentAlt: Color(0xFFEA7A00),
    accentWarm: Color(0xFFB4340A),
    safe: Color(0xFF047857),
    warn: Color(0xFFA35A05),
    danger: Color(0xFFB01E17),
    text: Color(0xFF0B0B0E),
    textSecondary: Color(0xFF4B4B55),
    textMuted: Color(0xFF6B6B76),
    mutedDeco: Color(0xFFA1A1AA),
    onAccent: Color(0xFFFFFFFF),
    heroSurface: [Color(0xFFFFFFFF), Color(0xFFFDF8F5), Color(0xFFFBF3EC)],
    heroBorder: Color(0xFFF0D9C7),
    segmentSurface: Color(0xFFF4F4F6),
    segmentSelected: [Color(0xFFFFF1E8), Color(0xFFFFE7D8)],
    heroAmount: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0600A), Color(0xFFE04000)],
    ),
    cardShadow: [
      BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x0A000000), offset: Offset(0, 8), blurRadius: 24),
    ],
    isDark: false,
  );

  @override
  SbPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHi,
    Color? border,
    Color? borderHi,
    Color? accent,
    Color? accentAlt,
    Color? accentWarm,
    Color? safe,
    Color? warn,
    Color? danger,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? mutedDeco,
    Color? onAccent,
    List<Color>? heroSurface,
    Color? heroBorder,
    List<Color>? segmentSelected,
    Color? segmentSurface,
    Gradient? heroAmount,
    List<BoxShadow>? cardShadow,
    bool? isDark,
  }) {
    return SbPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHi: surfaceHi ?? this.surfaceHi,
      border: border ?? this.border,
      borderHi: borderHi ?? this.borderHi,
      accent: accent ?? this.accent,
      accentAlt: accentAlt ?? this.accentAlt,
      accentWarm: accentWarm ?? this.accentWarm,
      safe: safe ?? this.safe,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      mutedDeco: mutedDeco ?? this.mutedDeco,
      onAccent: onAccent ?? this.onAccent,
      heroSurface: heroSurface ?? this.heroSurface,
      heroBorder: heroBorder ?? this.heroBorder,
      segmentSurface: segmentSurface ?? this.segmentSurface,
      segmentSelected: segmentSelected ?? this.segmentSelected,
      heroAmount: heroAmount ?? this.heroAmount,
      cardShadow: cardShadow ?? this.cardShadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  SbPalette lerp(covariant SbPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SbPalette(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceHi: mix(surfaceHi, other.surfaceHi),
      border: mix(border, other.border),
      borderHi: mix(borderHi, other.borderHi),
      accent: mix(accent, other.accent),
      accentAlt: mix(accentAlt, other.accentAlt),
      accentWarm: mix(accentWarm, other.accentWarm),
      safe: mix(safe, other.safe),
      warn: mix(warn, other.warn),
      danger: mix(danger, other.danger),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      mutedDeco: mix(mutedDeco, other.mutedDeco),
      onAccent: mix(onAccent, other.onAccent),
      heroSurface: t < 0.5 ? heroSurface : other.heroSurface,
      heroBorder: mix(heroBorder, other.heroBorder),
      segmentSurface: mix(segmentSurface, other.segmentSurface),
      segmentSelected: t < 0.5 ? segmentSelected : other.segmentSelected,
      heroAmount: t < 0.5 ? heroAmount : other.heroAmount,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// `context.sb.text` — the only way a widget should read a semantic colour.
extension SbThemeContext on BuildContext {
  SbPalette get sb =>
      Theme.of(this).extension<SbPalette>() ?? SbPalette.dark;
}
