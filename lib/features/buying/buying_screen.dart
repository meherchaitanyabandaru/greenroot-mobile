import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../buyer/buyer_tab.dart';
import '../manager/manager_work_tab.dart';
import '../owner/owner_tab.dart';

/// Role-aware Buying tab wrapper.
///
/// Routing logic:
///   BUYER only      → BuyerTab   (view quotations, track orders)
///   NURSERY_OWNER   → OwnerTab   (owner's buying view — their own purchases)
///   MANAGER         → ManagerWorkTab  (manager reuses Work tab in Buying position)
///
/// Each role's actual screen lives in its own module folder:
///   lib/features/buyer/buyer_tab.dart
///   lib/features/owner/owner_tab.dart
///   lib/features/manager/manager_work_tab.dart
class BuyingScreen extends ConsumerWidget {
  const BuyingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (caps.isNurseryOwner) return const OwnerTab();
    if (caps.isManager) return const ManagerWorkTab();
    return const BuyerTab();
  }
}
