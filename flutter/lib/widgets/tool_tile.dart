import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

/// Brand monogram tile.
///
/// The app ships without third-party logos (trademark safety, and it keeps the
/// bundle small): each tool gets a two-letter monogram tinted with its brand
/// hue. The glyph text is lifted toward white so it clears 4.5:1 on the tint.
class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.mark,
    required this.brandColor,
    this.size = 30,
  });

  final String mark;
  final Color brandColor;
  final double size;

  /// Mixes [brandColor] toward white — keeps the hue, fixes contrast.
  static Color _lift(Color c, [double amount = 0.52]) =>
      Color.lerp(c, const Color(0xFFFFFFFF), amount)!;

  @override
  Widget build(BuildContext context) {
    final radius = size * (size >= 44 ? 12 / 44 : 10 / 30);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandColor.withValues(alpha: 0.24),
            brandColor.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: brandColor.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        mark,
        style: TextStyle(
          fontFamily: SbFonts.mono,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.03 * size * 0.32,
          height: 1,
          color: _lift(brandColor),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
