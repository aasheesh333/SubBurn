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

abstract final class SbMotion {
  static const pulse = Duration(milliseconds: 2400);
  static const quick = Duration(milliseconds: 180);
}
