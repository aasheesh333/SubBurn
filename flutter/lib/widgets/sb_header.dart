import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';
import '../widgets/press_scale.dart';

/// The one header used by every screen.
///
/// Before this each screen rolled its own top row: the dashboard had a logo and
/// a 13 px wordmark, Renewals used a 22 px `h2`, Controls the same but without
/// the back affordance, and the detail screen had a 44 px icon button. Heights,
/// title sizes, padding and trailing chip placement all differed, which read as
/// four different apps. This widget is the single definition.
///
/// Spec: 48 px tall, 16 px page inset, title at `h3` (16 px), 44 px leading
/// tap target, trailing slot right-aligned.
class SbHeader extends StatelessWidget {
  const SbHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.onBack,
    this.showLogo = false,
    this.subtitle,
  });

  /// Screen title. Ignored when [showLogo] is set (the dashboard shows the
  /// wordmark instead of a title).
  final String title;

  final Widget? leading;
  final Widget? trailing;

  /// Renders a back button in the leading slot.
  final VoidCallback? onBack;

  /// Dashboard only: flame mark + SUBBURN wordmark.
  final bool showLogo;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 48 is the Figma height at 1x; with a subtitle at 200 % the two lines
      // need more, so the header grows instead of clipping.
      height: subtitle == null
          ? 48
          : 48 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            _IconTap(
              icon: Icons.chevron_left_rounded,
              label: 'Back',
              onTap: onBack!,
            ),
            const SizedBox(width: SbSpace.x2),
          ],
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SbSpace.x2),
          ],
          if (showLogo) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SbRadius.tile),
                gradient: context.sb.cta,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: context.sb.onAccent,
              ),
            ),
            const SizedBox(width: SbSpace.x2),
            // Flexible, not fixed: at 130 % text the wordmark plus the trailing
            // chip is wider than a 320 dp header.
            Flexible(
              child: Text(
                'SUBBURN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SbType.section.copyWith(
                  letterSpacing: 0.15 * 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) const Spacer(),
          ] else if (title.isNotEmpty)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SbType.h3.copyWith(color: context.sb.text),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SbType.micro.copyWith(
                        fontSize: 9,
                        color: context.sb.textMuted,
                        letterSpacing: 0.02,
                      ),
                    ),
                ],
              ),
            )
          else
            const Spacer(),
          if (trailing != null) ...[
            const SizedBox(width: SbSpace.x2),
            // Trailing chrome (badges, currency chip) is allowed to shrink a
            // little rather than stealing the whole title column — before this
            // a "v1.0.0 (1)" chip pushed the subtitle to "no account…".
            Flexible(
              flex: 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 44 × 44 icon button — the only tappable icon shape in a header.
class SbIconButton extends StatelessWidget {
  const SbIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _IconTap(
        icon: icon,
        label: label,
        onTap: onTap,
      );
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadius.tile),
        child: PressScale(
          child: Container(
            width: SbSize.minTapTarget,
            height: SbSize.minTapTarget,
            decoration: BoxDecoration(
              color: context.sb.surface,
              borderRadius: BorderRadius.circular(SbRadius.tile),
              border: Border.all(color: context.sb.border),
            ),
            child: Icon(icon, size: 20, color: context.sb.text),
          ),
        ),
      ),
    );
  }
}
