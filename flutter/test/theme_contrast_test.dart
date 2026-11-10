import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subburn/core/theme/app_theme.dart';
import 'package:subburn/core/theme/theme_tokens.dart';

/// WCAG 2.1 contrast checks for both palettes.
///
/// The light theme was added after the dark-only design, and the first attempt
/// shipped amber-on-white captions at ~2.1:1. These tests are the guard: every
/// semantic pairing the app actually renders is measured, in both brightnesses.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Blends [fg] over [bg] the way a card tint actually renders.
Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

void main() {
  for (final entry in {
    'dark': SbPalette.dark,
    'light': SbPalette.light,
  }.entries) {
    final name = entry.key;
    final p = entry.value;

    group('$name palette contrast', () {
      /// [min] is 4.5 for body text, 3.0 for large text and UI glyphs.
      void expectPairing(
        String label,
        Color fg,
        Color bg, {
        double min = 4.5,
      }) {
        final ratio = contrast(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(min),
          reason: '$name: $label is ${ratio.toStringAsFixed(2)}:1 '
              '(needs $min:1)',
        );
      }

      test('primary and secondary text on every surface', () {
        for (final surface in [p.bg, p.surface, p.surfaceHi]) {
          expectPairing('text on surface', p.text, surface);
          expectPairing('textSecondary on surface', p.textSecondary, surface);
          // Captions are 8-10 px: AA still requires 4.5:1 at that size.
          expectPairing('textMuted on surface', p.textMuted, surface);
        }
      });

      test('accent text on background and surface', () {
        expectPairing('accentWarm on bg', p.accentWarm, p.bg);
        expectPairing('accentWarm on surface', p.accentWarm, p.surface);
        // Accent is used for large numbers and UI glyphs, not body copy.
        expectPairing('accent on bg', p.accent, p.bg, min: 3);
      });

      test('semantic tones used as 8-12 px labels', () {
        expectPairing('safe on surface', p.safe, p.surface);
        expectPairing('warn on surface', p.warn, p.surface);
        expectPairing('danger on surface', p.danger, p.surface);
      });

      test('text on an accent-filled button', () {
        expectPairing('onAccent on accent', p.onAccent, p.accent, min: 3);
      });

      test('tonal surfaces stay readable', () {
        // Ghost rows and the callout tint the surface at 7 %.
        final warnTint = over(p.warn.withValues(alpha: 0.07), p.surface);
        expectPairing('text on warn tint', p.text, warnTint);
        expectPairing('textMuted on warn tint', p.textMuted, warnTint);
        expectPairing('warn on warn tint', p.warn, warnTint);

        // Hero card surface stops.
        for (final stop in p.heroSurface) {
          expectPairing('text on hero', p.text, stop);
          expectPairing('textSecondary on hero', p.textSecondary, stop);
        }
      });

      test('selected segment label', () {
        final selected = over(p.segmentSelected.first, p.segmentSurface);
        expectPairing('text on selected segment', p.text, selected);
      });
    });
  }

  group('theme wiring', () {
    test('both themes expose the palette extension', () {
      expect(AppTheme.dark.extension<SbPalette>(), SbPalette.dark);
      expect(AppTheme.light.extension<SbPalette>(), SbPalette.light);
    });

    test('brightness follows the palette', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.scaffoldBackgroundColor, SbPalette.light.bg);
    });

    test('scaffold background is never the dark canvas in light mode', () {
      expect(SbPalette.light.bg, isNot(SbPalette.dark.bg));
      expect(SbPalette.light.text, isNot(SbPalette.dark.text));
    });
  });
}
