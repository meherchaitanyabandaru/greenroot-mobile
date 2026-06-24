import 'package:flutter/material.dart';
import '../errors/app_error.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  final AppError? error;
  final String? message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.error,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final displayMessage = message ??
        error?.message ??
        'Something went wrong. Please try again.';

    final isNetwork = error is NetworkError || error is TimeoutError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.red100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 36,
                color: AppColors.red600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isNetwork ? 'No Connection' : 'Something Went Wrong',
              style: AppTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              displayMessage,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x2l),
              AppButton(
                label: 'Try Again',
                onPressed: onRetry,
                leadingIcon: Icons.refresh_rounded,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
