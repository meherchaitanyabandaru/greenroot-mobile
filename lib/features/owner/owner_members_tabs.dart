part of 'owner_members_screen.dart';

class _ManagersTab extends ConsumerWidget {
  final int nurseryId;
  final String nurseryName;
  final List<NurseryManager> managers;
  final List<NurseryInvite> invites;

  const _ManagersTab({
    required this.nurseryId,
    required this.nurseryName,
    required this.managers,
    required this.invites,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(membersProvider(nurseryId).notifier).load(),
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          AppButton(
            buttonKey: const Key(TestKeys.inviteManagerButton),
            label: 'Invite Manager / Gumastha',
            leadingIcon: Icons.person_add_rounded,
            onPressed: () => _showInviteSheet(context, ref, 'MANAGER_INVITE'),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Active Managers', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          if (managers.isEmpty)
            const EmptyState(
              icon: Icons.manage_accounts_outlined,
              title: 'No managers yet',
              subtitle: 'Invite a manager to help run your nursery operations.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < managers.length; i++) ...[
                    _RemovableMemberTile(
                      icon: Icons.manage_accounts_rounded,
                      name: managers[i].displayName,
                      subtitle: managers[i].mobile ??
                          managers[i].email ??
                          'No contact',
                      badge: managers[i].role,
                      badgeColor: AppColors.primaryMain,
                      onRemove: () => _confirmRemove(context, ref, managers[i]),
                    ),
                    if (i < managers.length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                ],
              ),
            ),
          if (invites.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2l),
            const Text('Pending Invites', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.sm),
            ...invites.map((inv) => _InviteCard(invite: inv)),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  void _showInviteSheet(
    BuildContext context,
    WidgetRef ref,
    String inviteType,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        nurseryId: nurseryId,
        nurseryName: nurseryName,
        inviteType: inviteType,
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    NurseryManager m,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Manager'),
        content: Text(
          'Remove ${m.displayName} from your nursery? They will lose access immediately and must be re-invited to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red600),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(membersProvider(nurseryId).notifier)
          .removeManager(m.userId);
    }
  }
}

// ── Drivers Tab ───────────────────────────────────────────────────────────────

class _DriversTab extends ConsumerWidget {
  final int nurseryId;
  final String nurseryName;
  final List<NurseryDriver> drivers;

  const _DriversTab({
    required this.nurseryId,
    required this.nurseryName,
    required this.drivers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(membersProvider(nurseryId).notifier).load(),
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          AppButton(
            label: 'Invite Driver',
            leadingIcon: Icons.local_shipping_rounded,
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _InviteSheet(
                nurseryId: nurseryId,
                nurseryName: nurseryName,
                inviteType: 'DRIVER_INVITE',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Connected Drivers', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          if (drivers.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No drivers connected',
              subtitle:
                  'Invite a registered driver. They accept by scanning the invite QR.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < drivers.length; i++) ...[
                    _RemovableMemberTile(
                      icon: Icons.local_shipping_rounded,
                      name: drivers[i].displayName,
                      subtitle: drivers[i].mobile ??
                          'Driver #${drivers[i].driverUserId}',
                      badge: drivers[i].connectionStatus,
                      badgeColor: AppColors.forest600,
                      onRemove: () =>
                          _confirmDisconnect(context, ref, drivers[i]),
                    ),
                    if (i < drivers.length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    WidgetRef ref,
    NurseryDriver d,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect Driver'),
        content: Text(
          'Disconnect ${d.displayName} from your nursery? They will lose access to your trips immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red600),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(membersProvider(nurseryId).notifier)
          .disconnectDriver(d.driverUserId);
    }
  }
}

// ── Customers Tab ─────────────────────────────────────────────────────────────

class _CustomersTab extends ConsumerWidget {
  final int nurseryId;
  final String nurseryName;
  final List<NurseryCustomer> customers;
  final List<NurseryInvite> pendingInvites;

  const _CustomersTab({
    required this.nurseryId,
    required this.nurseryName,
    required this.customers,
    required this.pendingInvites,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(membersProvider(nurseryId).notifier).load(),
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Invite Customer button
          AppButton(
            buttonKey: const Key(TestKeys.inviteCustomerButton),
            label: 'Invite Customer',
            leadingIcon: Icons.person_add_rounded,
            onPressed: () => _showInviteSheet(context, ref),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Linked customers (real user data from /nurseries/{id}/customers)
          const Text('Linked Customers', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          if (customers.isEmpty)
            const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No customers yet',
              subtitle:
                  'Invite customers to place orders through your nursery.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < customers.length; i++) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.forest100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.primaryMain,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        customers[i].displayName,
                        style: AppTypography.label,
                      ),
                      subtitle: Text(
                        customers[i].mobile.isNotEmpty
                            ? customers[i].mobile
                            : (customers[i].email ?? ''),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forest600.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'CUSTOMER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest600,
                          ),
                        ),
                      ),
                    ),
                    if (i < customers.length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                ],
              ),
            ),

          // Pending invites
          if (pendingInvites.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2l),
            const Text('Pending Invites', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.sm),
            ...pendingInvites.map((inv) => _InviteCard(invite: inv)),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        nurseryId: nurseryId,
        nurseryName: nurseryName,
        inviteType: 'CUSTOMER_INVITE',
      ),
    );
  }
}

// ── Invite Creation Sheet ─────────────────────────────────────────────────────
