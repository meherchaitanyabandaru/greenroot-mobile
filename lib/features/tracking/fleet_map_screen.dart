import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../dispatches/dispatches.dart';
import 'tracking.dart';

class FleetMapScreen extends ConsumerStatefulWidget {
  const FleetMapScreen({super.key});

  @override
  ConsumerState<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends ConsumerState<FleetMapScreen> {
  final _mapController = MapController();
  List<_PinData> _pins = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFleet();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadFleet(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadFleet({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final repo = ref.read(dispatchRepositoryProvider);
      final trackingRepo = ref.read(trackingRepositoryProvider);

      // Load in-transit dispatches
      final (dispatches, _) =
          await repo.listDispatches(status: 'IN_TRANSIT', perPage: 50);

      // For each dispatch, fetch latest tracking point
      final pins = <_PinData>[];
      for (final d in dispatches) {
        final latest = await trackingRepo.getDispatchTrackingLatest(d.id);
        if (latest != null) {
          pins.add(_PinData(dispatch: d, point: latest));
        }
      }

      if (mounted) {
        setState(() {
          _pins = pins;
          _loading = false;
        });
        if (pins.isNotEmpty) {
          _mapController.move(
            LatLng(pins.first.point.latitude, pins.first.point.longitude),
            12,
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Fleet Map'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadFleet(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (_loading)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryMain),
                        ),
                        SizedBox(width: 8),
                        Text('Fetching locations…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_loading && _pins.isEmpty)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text('No active dispatches with tracking data'),
                  ),
                ),
              ),
            ),
          if (_pins.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomSheet(),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _pins.isNotEmpty
        ? LatLng(_pins.first.point.latitude, _pins.first.point.longitude)
        : const LatLng(20.5937, 78.9629); // center of India

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _pins.isNotEmpty ? 12 : 5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.greenroot.greenroot_mobile',
        ),
        MarkerLayer(
          markers: _pins.map((pin) {
            return Marker(
              point: LatLng(pin.point.latitude, pin.point.longitude),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => context.push('/dispatches/${pin.dispatch.id}/track'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pin.dispatch.vehicleNumber ??
                            pin.dispatch.dispatchCode
                                .substring(0, min(6, pin.dispatch.dispatchCode.length)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_pin,
                      color: AppColors.primaryMain,
                      size: 28,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      height: 140,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Text(
              '${_pins.length} vehicle${_pins.length == 1 ? '' : 's'} on map',
              style: AppTypography.label,
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _pins.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final pin = _pins[index];
                return GestureDetector(
                  onTap: () {
                    _mapController.move(
                      LatLng(pin.point.latitude, pin.point.longitude),
                      15,
                    );
                  },
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.forest50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 14, color: AppColors.primaryMain),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pin.dispatch.vehicleNumber ??
                                    pin.dispatch.dispatchCode,
                                style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (pin.dispatch.driverName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            pin.dispatch.driverName!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context
                              .push('/dispatches/${pin.dispatch.id}/track'),
                          child: Text(
                            'View Route →',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.primaryMid,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

int min(int a, int b) => a < b ? a : b;

class _PinData {
  final Dispatch dispatch;
  final TrackingPoint point;
  const _PinData({required this.dispatch, required this.point});
}
