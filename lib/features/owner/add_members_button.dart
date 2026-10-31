import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/providers/session_provider.dart';

/// For an empty manager or customer picker: closes the sheet and opens where
/// people are invited. Shown only to who can invite them: managers by the
/// owner (members screen); customers by the owner or a manager (Connections).
class AddMembersButton extends ConsumerWidget {
  final bool customers;

  const AddMembersButton.managers({super.key}) : customers = false;
  const AddMembersButton.customers({super.key}) : customers = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;
    final id = caps.ownedNurseryId;
    final String route;
    if (caps.isNurseryOwner && id != null) {
      final name = Uri.encodeComponent(caps.ownedNurseryName ?? 'My Nursery');
      route = '/nursery/members?id=$id&name=$name&tab=${customers ? 2 : 0}';
    } else if (customers && caps.isManager) {
      route = '/connections';
    } else {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: Text(customers ? 'Add customers' : 'Add managers'),
      onPressed: () {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(route);
      },
    );
  }
}
