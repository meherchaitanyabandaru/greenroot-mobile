import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Buyer Buying tab — the full tab screen shown to BUYER-only users.
/// Unique actions: view incoming quotations (accept/reject), view own orders, track deliveries.
/// Buyers CANNOT create orders or quotations — only respond to nursery-initiated ones.
class BuyerTab extends StatelessWidget {
  const BuyerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Text('Buyer — Buying Tab', style: AppTypography.h3)),
    );
  }
}
