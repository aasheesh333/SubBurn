import 'package:flutter/material.dart';

import '../theme/subburn_tokens.dart';

/// Primary CTA: burn gradient, 52 px tall, orange bloom underneath.
///
/// [trailing] renders the mono price chip after a hairline, e.g. `₹1,660 /mo`.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailing,
    this.height = 52,
    this.variant = ButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? trailing;
  final double height;
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: trailing == null ? label : '$label, $trailing',
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: variant == ButtonVariant.primary ? Colors.transparent : SbColors.surface,
          borderRadius: BorderRadius.circular(SbRadius.button),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(SbRadius.button),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SbRadius.button),
                gradient: variant == ButtonVariant.primary ? SbGradients.burn : null,
                border: variant == ButtonVariant.primary
                    ? null
                    : Border.all(
                        color: variant == ButtonVariant.danger
                            ? SbColors.danger.withValues(alpha: 0.34)
                            : SbColors.border,
                      ),
                boxShadow: variant == ButtonVariant.primary
                    ? const [SbShadow.cardInner, SbShadow.ctaGlow]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: variant == ButtonVariant.primary
                          ? const Color(0xFF180900)
                          : variant == ButtonVariant.danger
                              ? const Color(0xFFF87171)
                              : SbColors.text,
                    ),
                    const SizedBox(width: SbSpace.x2),
                  ],
                  Text(
                    label,
                    style: SbType.section.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.015 * 13,
                      color: switch (variant) {
                        ButtonVariant.primary => const Color(0xFF180900),
                        ButtonVariant.danger => const Color(0xFFF87171),
                        ButtonVariant.outline => SbColors.text,
                      },
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.only(left: 9),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0x33000000)),
                        ),
                      ),
                      child: Text(
                        trailing!,
                        style: SbType.micro.copyWith(
                          fontSize: 10.5,
                          color: const Color(0xFF180900).withValues(alpha: 0.7),
                          letterSpacing: -0.02,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ButtonVariant { primary, outline, danger }
