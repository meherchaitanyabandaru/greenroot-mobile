import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, outlined, ghost, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool expand;

  /// Key applied to the inner Elevated/Outlined/TextButton itself, distinct
  /// from the widget's own [key]. Automation drivers (e.g. Appium's Flutter
  /// integration driver) locate the actual tappable control via this, since
  /// [key] only marks the outer sizing wrapper in the widget tree.
  final Key? buttonKey;

  const AppButton({
    super.key,
    this.buttonKey,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.expand = true,
  });

  const AppButton.outlined({
    super.key,
    this.buttonKey,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.expand = true,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.ghost({
    super.key,
    this.buttonKey,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    this.buttonKey,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      AppButtonSize.sm => AppSpacing.buttonHeightSm,
      AppButtonSize.md => AppSpacing.buttonHeight,
      AppButtonSize.lg => 60.0,
    };

    final textStyle = size == AppButtonSize.sm
        ? AppTypography.buttonSm
        : AppTypography.button;

    Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_loadingColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: textStyle),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: 18),
              ],
            ],
          );

    if (expand) {
      child = Center(child: child);
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: switch (variant) {
        AppButtonVariant.primary => ElevatedButton(
            key: buttonKey,
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.slate200,
              disabledForegroundColor: AppColors.slate400,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
              padding: EdgeInsets.zero,
              // No elevation override here -- falls through to
              // ElevatedButtonThemeData's resolveWith (elevation 3, a
              // primaryMain-tinted shadow), which this used to flatten to 0.
              // A primary CTA with zero elevation reads as inert/disabled
              // rather than the main action on the screen.
            ),
            child: child,
          ),
        AppButtonVariant.outlined => OutlinedButton(
            key: buttonKey,
            onPressed: effectiveOnPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryMain,
              side: BorderSide(
                color: effectiveOnPressed == null
                    ? AppColors.slate300
                    : AppColors.primaryMain,
                width: 1.5,
              ),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
              padding: EdgeInsets.zero,
            ),
            child: child,
          ),
        AppButtonVariant.ghost => TextButton(
            key: buttonKey,
            onPressed: effectiveOnPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryMain,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: child,
          ),
        AppButtonVariant.danger => ElevatedButton(
            key: buttonKey,
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red600,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
              // Explicit (not inherited from the theme, which shadows in
              // primaryMain green -- wrong tint under a red button).
              elevation: 3,
              shadowColor: AppColors.red600.withValues(alpha: 0.28),
              padding: EdgeInsets.zero,
            ),
            child: child,
          ),
      },
    );
  }

  Color get _loadingColor => switch (variant) {
    AppButtonVariant.primary || AppButtonVariant.danger => Colors.white,
    AppButtonVariant.outlined || AppButtonVariant.ghost => AppColors.primaryMain,
  };
}
