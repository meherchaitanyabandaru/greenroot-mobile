import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Manager Work tab — the full Work tab screen for managers.
/// Unique actions: create/manage orders, approve quotations, start loading,
/// create dispatches. Managers cannot manage inventory or team membership.
class ManagerWorkTab extends StatelessWidget {
  const ManagerWorkTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
          child: Text('Manager — Work Tab', style: AppTypography.h3)),
    );
  }
}
