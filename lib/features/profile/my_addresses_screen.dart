import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart' show ApiClient, apiClientProvider;
import '../../core/services/geocoding/geocoding_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/domain/rbac/roles.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'address_map_picker_screen.dart';

part 'address_form_screen.dart';
part 'my_addresses_data.dart';

// ── Address model ─────────────────────────────────────────────────────────────
// Matches user_addresses DB columns exactly.

class MyAddressesScreen extends ConsumerStatefulWidget {
  final int? nurseryId;

  const MyAddressesScreen({super.key, this.nurseryId});

  @override
  ConsumerState<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends ConsumerState<MyAddressesScreen> {
  List<UserAddress> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = ref.read(sessionProvider).user?.id;
      if (userId == null) throw Exception('Not logged in');
      final repo = ref.read(userAddressRepositoryProvider);
      final list = widget.nurseryId == null
          ? await repo.listAddresses(userId)
          : await repo.listNurseryAddresses(widget.nurseryId!);
      if (mounted) setState(() => _addresses = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Two-step flow: map picker → form (new) | form only (edit) ────────────

  Future<void> _openForm([UserAddress? existing]) async {
    final isEdit = existing != null;
    MapPickResult? mapResult;

    if (!isEdit) {
      // Step 1 — map picker
      mapResult = await Navigator.push<MapPickResult>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const AddressMapPickerScreen(),
        ),
      );
      if (mapResult == null || !mounted) return; // user cancelled the map
    }

    // Step 2 — address form
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddressFormScreen(
          existing: existing,
          mapResult: mapResult,
          onSave: (form) async {
            final userId = ref.read(sessionProvider).user?.id;
            if (userId == null) return;
            final repo = ref.read(userAddressRepositoryProvider);
            if (existing == null) {
              widget.nurseryId == null
                  ? await repo.addAddress(userId, form)
                  : await repo.addNurseryAddress(widget.nurseryId!, form);
            } else {
              widget.nurseryId == null
                  ? await repo.updateAddress(existing.id, form)
                  : await repo.updateNurseryAddress(existing.id, form);
            }
            // Reload: a new default clears the old one's badge on the server.
            if (mounted) _load();
          },
        ),
      ),
    );
  }

  Future<void> _delete(UserAddress a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${a.displayAddress}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.red600),),),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (widget.nurseryId == null) {
        await ref.read(userAddressRepositoryProvider).deleteAddress(a.id);
      } else {
        await ref
            .read(userAddressRepositoryProvider)
            .deleteNurseryAddress(a.id);
      }
      if (mounted) _load(); // the server may promote another default
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          widget.nurseryId == null ? 'My Addresses' : 'Nursery Addresses',
          style: AppTypography.h3,
        ),
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMain),)
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _addresses.isEmpty
                  ? _EmptyState(
                      onAdd: () => _openForm(),
                      showOwnerHint: widget.nurseryId == null &&
                          ref
                              .watch(sessionProvider)
                              .roles
                              .contains(AppRole.nurseryOwner),
                    )
                  : _AddressListView(
                      addresses: _addresses,
                      onEdit: (a) => _openForm(a),
                      // A nursery keeps at least one (pickup) address.
                      onDelete: widget.nurseryId != null &&
                              _addresses.length == 1
                          ? null
                          : _delete,
                      onAdd: () => _openForm(),
                      onRefresh: _load,
                    ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool showOwnerHint;

  const _EmptyState({required this.onAdd, this.showOwnerHint = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle,),
            child: const Icon(Icons.location_on_outlined,
                size: 52, color: AppColors.primaryMain,),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('No personal delivery addresses yet.',
              style: AppTypography.h3, textAlign: TextAlign.center,),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These are your personal delivery addresses\nfor receiving orders.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (showOwnerHint) ...[
            const SizedBox(height: AppSpacing.x2l),
            const _OwnerAddressHint(),
          ],
          const Spacer(),
          _AddButton(onTap: onAdd),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

// ── Owner hint banner ─────────────────────────────────────────────────────────
// Shown only when the user has NURSERY_OWNER role and personal address list
// is empty — prevents confusion between personal and nursery addresses.

class _OwnerAddressHint extends ConsumerWidget {
  const _OwnerAddressHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurseryId =
        ref.watch(sessionProvider.select((s) => s.capabilities.ownedNurseryId));
    // A link, not just directions: it opens the nursery's addresses directly.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: nurseryId == null
          ? null
          : () => context.push('/nursery/addresses', extra: nurseryId),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primaryMain.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.store_outlined,
              size: 18, color: AppColors.primaryMain,),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                children: const [
                  TextSpan(text: 'Looking for your nursery address? '),
                  TextSpan(
                    text: 'Open nursery addresses ›',
                    style: TextStyle(
                        color: AppColors.primaryMain,
                        fontWeight: FontWeight.w700,),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Address list ──────────────────────────────────────────────────────────────

class _AddressListView extends StatelessWidget {
  final List<UserAddress> addresses;
  final void Function(UserAddress) onEdit;
  final void Function(UserAddress)? onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  const _AddressListView({
    required this.addresses,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.primaryMain,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                  AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md,),
              itemCount: addresses.length,
              itemBuilder: (_, i) => _AddressCard(
                address: addresses[i],
                onEdit: () => onEdit(addresses[i]),
                onDelete: onDelete == null
                    ? null
                    : () => onDelete!(addresses[i]),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,),
          child: _AddButton(onTap: onAdd),
        ),
      ],
    );
  }
}

// ── Address card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _AddressCard(
      {required this.address, required this.onEdit, this.onDelete,});

  IconData get _icon {
    switch (address.addressType?.toUpperCase()) {
      case 'HOME':
        return Icons.home_outlined;
      case 'WORK':
      case 'OFFICE':
        return Icons.business_outlined;
      case 'FARM':
        return Icons.agriculture_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: address.isDefault
                ? AppColors.primaryMain.withValues(alpha: 0.4)
                : AppColors.border,),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(10),),
              child: Icon(_icon, color: AppColors.primaryMain, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (address.addressType?.isNotEmpty == true)
                        _Chip(address.addressType!.toUpperCase(),
                            bg: AppColors.forest100, fg: AppColors.primaryMain,),
                      if (address.isDefault)
                        const _Chip('DEFAULT',
                            bg: AppColors.primaryMain, fg: Colors.white,),
                    ],
                  ),
                  if (address.contactName?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(address.contactName!,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),),
                  ],
                  if (address.contactMobile?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(address.contactMobile!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    address.displayAddress,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 36,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],),),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppColors.red600,),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: AppColors.red600),),
                      ],),),
                ],
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.textMuted,),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit address — full-screen form ─────────────────────────────────────
//
// New address flow:
//   AddressMapPickerScreen → MapPickResult → AddressFormScreen
//   City, State, Pincode come from map (locked / read-only).
//   Address Line 1, Line 2, Label, Name, Mobile are always manually entered.
//
// Edit address flow:
//   AddressFormScreen only (pre-filled from existing data, all fields editable).
