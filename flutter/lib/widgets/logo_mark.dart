import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

/// The brand mark, drawn from the same artwork as the launcher icon.
///
/// One widget so the header chip and the legal page cannot drift apart: both
/// used to paint a flame glyph on an orange gradient, which stopped matching
/// the launcher icon the moment the icon became the receipt illustration.
///
/// The asset is a 512 px downscale of the launcher artwork, clipped to the
/// same 22 % corner radius the splash tile uses — so the in-app mark, the
/// splash and the home-screen icon are visibly the same object.
class SbLogoMark extends StatelessWidget {
  const SbLogoMark({super.key, this.size = 32});

  /// Visual size in logical pixels. Renders the 512 px asset downscaled, so
  /// it stays sharp on every density.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'SubBurn',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          // Brand cream behind the artwork: the first frame, before the asset
          // finishes decoding, shows the mark's own background instead of an
          // empty bordered square.
          color: const Color(0xFFFCDECA),
          // Hairline so the cream artwork keeps an edge on a white surface.
          border: Border.all(color: context.sb.border, width: SbSize.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/brand/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
