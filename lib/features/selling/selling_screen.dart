import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../manager/manager_work_tab.dart';
import '../owner/owner_tab.dart';

/// Role-aware Selling / Work tab wrapper.
///
/// Routing logic:
///   NURSERY_OWNER → OwnerTab        (full selling ops: orders, quotations, inventory, team)
///   MANAGER       → ManagerWorkTab  (assigned work: loading, dispatch, quotation approval)
///
/// Each role's actual screen lives in its own module folder:
///   lib/features/owner/owner_tab.dart
///   lib/features/manager/manager_work_tab.dart
///
/// Note: BUYER and DRIVER never see this tab (filtered out in main_shell.dart _buildTabs).
class SellingScreen extends ConsumerWidget {
  const SellingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (caps.isManager) return const ManagerWorkTab();
    return const OwnerTab();
  }
}
