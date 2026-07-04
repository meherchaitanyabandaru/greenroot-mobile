import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Owner Selling tab — the full Selling tab screen for nursery owners.
/// Unique actions: manage orders, create quotations, loading workflow,
/// dispatch management, inventory, team members, plant sourcing.
class OwnerTab extends StatelessWidget {
  const OwnerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body:
          Center(child: Text('Owner — Selling Tab', style: AppTypography.h3)),
    );
  }
}
