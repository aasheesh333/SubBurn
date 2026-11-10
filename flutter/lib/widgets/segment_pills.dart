import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

/// Segmented pill group used for Billing cycle / Currency / Usage guilt.
///
/// Generic over `T` so the sheet can bind it directly to its model.
class SegmentPills<T> extends StatelessWidget {
  const SegmentPills({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.trailingOf,
    this.leadingOf,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  /// Optional right-aligned mono hint, e.g. `-17%`.
  final String? Function(T)? trailingOf;

  /// Optional leading dot colour, e.g. usage-guilt green / amber.
  final Color? Function(T)? leadingOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SbSpace.x1),
      decoration: BoxDecoration(
        color: context.sb.segmentSurface,
        borderRadius: BorderRadius.circular(SbRadius.inner),
        border: Border.all(color: context.sb.border),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: _Segment(
                label: labelOf(v),
                trailing: trailingOf?.call(v),
                dot: leadingOf?.call(v),
                selected: v == selected,
                onTap: () => onChanged(v),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.dot,
  });

  final String label;
  final String? trailing;
  final Color? dot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glowDot = selected && dot != null && dot == context.sb.safe;
    final dotShadow = glowDot
        ? <BoxShadow>[
            BoxShadow(color: dot!.withValues(alpha: 0.9), blurRadius: 7),
          ]
        : null;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: SbSize.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: context.sb.segmentSelected,
                  )
                : null,
            border: Border.all(
              color: selected ? context.sb.accentAlt.withValues(alpha: 0.36) : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    const BoxShadow(
                      color: Color(0x4DFF4500),
                      offset: Offset(0, 4),
                      blurRadius: 14,
                      spreadRadius: -8,
                    ),
                    SbShadow.cardInner,
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    boxShadow: dotShadow,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: SbType.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.01 * 11,
                  color: selected ? context.sb.text : context.sb.textMuted,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 5),
                Text(
                  trailing!,
                  style: SbType.micro.copyWith(
                    fontSize: 8,
                    letterSpacing: 0.02,
                    color: selected ? context.sb.accentWarm : context.sb.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
