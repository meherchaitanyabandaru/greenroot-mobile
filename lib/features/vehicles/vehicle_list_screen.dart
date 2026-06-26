import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/pagination.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'vehicles.dart';

class VehicleListScreen extends ConsumerStatefulWidget {
  const VehicleListScreen({super.key});

  @override
  ConsumerState<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends ConsumerState<VehicleListScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vehicleListProvider.notifier).load();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(vehicleListProvider.notifier).loadMore();
    }
  }

  Future<void> _confirmDelete(Vehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text(
            'Remove ${vehicle.vehicleNumber}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red600),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final success = await ref
          .read(vehicleListProvider.notifier)
          .deleteVehicle(vehicle.id);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete vehicle')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleListProvider);
    final paged = state.paged;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicles'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(vehicleListProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/vehicles/create').then((_) {
          ref.read(vehicleListProvider.notifier).load();
        }),
        backgroundColor: AppColors.primaryMain,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(paged),
    );
  }

  Widget _buildBody(PagedState<Vehicle> paged) {
    if (paged.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain));
    }

    if (paged.error != null && paged.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(paged.error!.message, style: AppTypography.body),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(vehicleListProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (paged.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bus_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('No vehicles yet', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.xs),
            Text('Tap + to add your first vehicle',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(vehicleListProvider.notifier).load(),
      color: AppColors.primaryMain,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: paged.items.length + (paged.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == paged.items.length) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(color: AppColors.primaryMain),
            ));
          }
          final vehicle = paged.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Dismissible(
              key: ValueKey(vehicle.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  borderRadius: AppRadius.cardRadius,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.red600),
              ),
              confirmDismiss: (_) async {
                await _confirmDelete(vehicle);
                return false; // we handle deletion ourselves
              },
              child: _VehicleCard(
                vehicle: vehicle,
                onTap: () =>
                    context.push('/vehicles/${vehicle.id}/edit', extra: vehicle)
                        .then((_) {
                  ref.read(vehicleListProvider.notifier).load();
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;

  const _VehicleCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(vehicle.status);
    final statusBg = _statusBg(vehicle.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.directions_bus_rounded,
                  color: AppColors.primaryMain, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.vehicleNumber, style: AppTypography.label),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (vehicle.vehicleType != null) ...[
                        Text(vehicle.vehicleType!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary)),
                        if (vehicle.capacityKG != null)
                          Text(' · ${vehicle.capacityKG!.toInt()} kg',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                  if (vehicle.ownerName != null) ...[
                    const SizedBox(height: 2),
                    Text(vehicle.ownerName!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    vehicle.status,
                    style: AppTypography.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(vehicle.vehicleCode,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.primaryMid;
      case 'INACTIVE':
        return AppColors.textSecondary;
      case 'MAINTENANCE':
        return AppColors.amber600;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.forest100;
      case 'INACTIVE':
        return AppColors.slate100;
      case 'MAINTENANCE':
        return AppColors.amber100;
      default:
        return AppColors.slate100;
    }
  }
}
