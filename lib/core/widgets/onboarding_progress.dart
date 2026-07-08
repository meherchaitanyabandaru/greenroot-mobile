import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OnboardingProgress extends StatelessWidget {
  final int currentStep; // 1-indexed, 1–3

  const OnboardingProgress({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepDot(step: 1, currentStep: currentStep, label: 'Phone'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Divider(
              height: 2,
              thickness: 2,
              color: currentStep > 1 ? AppColors.primaryMain : AppColors.border,
            ),
          ),
        ),
        _StepDot(step: 2, currentStep: currentStep, label: 'Verify'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Divider(
              height: 2,
              thickness: 2,
              color: currentStep > 2 ? AppColors.primaryMain : AppColors.border,
            ),
          ),
        ),
        _StepDot(step: 3, currentStep: currentStep, label: 'Profile'),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final int currentStep;
  final String label;

  const _StepDot({
    required this.step,
    required this.currentStep,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = step < currentStep;
    final isActive = step == currentStep;
    final borderColor =
        isActive || isCompleted ? AppColors.primaryMain : AppColors.border;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? AppColors.primaryMain
                : Colors.transparent,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded,
                    size: 12, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textMuted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive || isCompleted
                ? AppColors.primaryMain
                : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
