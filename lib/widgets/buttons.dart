import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';
import 'basics.dart';

enum ButtonVariant { primary, ghost, alert }

/// Blueprint `.btn` / `.btn.ghost` / `.btn.alert` / `.btn.sm`.
class NabraButton extends StatelessWidget {
  const NabraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.small = false,
    this.loading = false,
  });

  const NabraButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.loading = false,
  }) : variant = ButtonVariant.ghost;

  const NabraButton.alert({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.loading = false,
  }) : variant = ButtonVariant.alert;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool small;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      ButtonVariant.primary => (AppColors.cyan, AppColors.onAccent, AppColors.cyan),
      ButtonVariant.ghost => (AppColors.transparent, AppColors.fg, AppColors.line),
      ButtonVariant.alert => (AppColors.alert, AppColors.onAlert, AppColors.alert),
    };
    final enabled = onPressed != null && !loading;
    final radius = small ? AppRadius.mdAll : AppRadius.lgAll;

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: small ? AppSizes.buttonHeightSm : AppSizes.buttonHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: AppSizes.sparkStroke, color: fg),
                    )
                  else if (icon != null)
                    Icon(icon, size: AppSizes.iconSm + 2, color: fg),
                  if (loading || icon != null) const Gap(AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.button.copyWith(color: fg, fontSize: small ? 13 : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
