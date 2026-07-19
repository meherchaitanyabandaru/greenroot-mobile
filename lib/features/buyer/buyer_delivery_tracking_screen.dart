import 'dart:async';
import 'dart:math' show min, max;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/map_widgets.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';
import '../tracking/tracking.dart';

String _formatDistance(double km) => km < 1
    ? '${(km * 1000).toStringAsFixed(0)} m'
    : '${km.toStringAsFixed(1)} km';

Color _dispatchStatusColor(String status) =>
    LifecyclePresenter.forBuyerDispatchStatus(status).color;

// ── Screen shell ───────────────────────────────────────────────────────────────

class BuyerDeliveryTrackingScreen extends ConsumerWidget {
  final int dispatchId;
  const BuyerDeliveryTrackingScreen({super.key, required this.dispatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dispatchDetailProvider(dispatchId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(dispatchDetailProvider(dispatchId)),
        ),
        data: (dispatch) => _BuyerDeliveryBody(
          key: ValueKey('${dispatch.id}-${dispatch.status}'),
          dispatch: dispatch,
          dispatchId: dispatchId,
        ),
      ),
    );
  }
}

// ── Stateful body ──────────────────────────────────────────────────────────────

class _BuyerDeliveryBody extends ConsumerStatefulWidget {
  final Dispatch dispatch;
  final int dispatchId;
  const _BuyerDeliveryBody(
      {super.key, required this.dispatch, required this.dispatchId});

  @override
  ConsumerState<_BuyerDeliveryBody> createState() => _BuyerDeliveryBodyState();
}

class _BuyerDeliveryBodyState extends ConsumerState<_BuyerDeliveryBody> {
  final _mapController = MapController();

  List<TrackingPoint> _trackingPts = [];
  LatLng? _loadingPointLatLng;
  LatLng? _deliveryPointLatLng;
  String? _nurseryName;
  bool _mapReady = false;
  bool _journeyExpanded = false;
  bool _plantsExpanded = false;
  Timer? _pollTimer;
  DateTime? _lastLocationAt;
  double? _approxDistanceKm;

  @override
  void initState() {
    super.initState();
    _fetchNurseryAndGeocode();
    _loadTracking();
    if (_isLive) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadTracking(silent: true),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  bool get _isLive =>
      widget.dispatch.status == 'IN_TRANSIT' ||
      widget.dispatch.status == 'DISPATCHED';

  // ── Data fetching ────────────────────────────────────────────────────────────

  Future<void> _loadTracking({bool silent = false}) async {
    try {
      final pts = await ref
          .read(trackingRepositoryProvider)
          .getDispatchTracking(widget.dispatchId);
      if (mounted) {
        setState(() {
          _trackingPts = pts;
          _lastLocationAt = pts.isEmpty
              ? null
              : DateTime.tryParse(pts.first.trackedAt)?.toLocal();
        });
        if (pts.isNotEmpty && _mapReady) _fitBounds();
        _updateApproxDistance();
      }
    } catch (_) {}
  }

  Future<void> _fetchNurseryAndGeocode() async {
    final nurseryId = widget.dispatch.sellerNurseryId;
    if (nurseryId != null) {
      try {
        final data = await ApiClient.instance.get<Map<String, dynamic>>(
          '/api/v1/nurseries/$nurseryId',
        );
        final n = (data['nursery'] ?? data) as Map<String, dynamic>;
        final name = n['name'] as String? ?? 'Nursery';
        String? addr;
        final addresses = n['addresses'] as List<dynamic>?;
        if (addresses != null && addresses.isNotEmpty) {
          final primary = addresses.firstWhere(
            (a) => a['is_primary'] == true,
            orElse: () => addresses.first,
          );
          final parts = <String>[
            if (primary['address_line1'] != null)
              primary['address_line1'] as String,
            if (primary['city'] != null) primary['city'] as String,
            if (primary['state'] != null) primary['state'] as String,
          ].where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) addr = parts.join(', ');
        }
        if (mounted) setState(() => _nurseryName = name);
        if (addr != null) {
          final ll = await _geocode(addr);
          if (ll != null && mounted) {
            setState(() => _loadingPointLatLng = ll);
          }
        }
      } catch (_) {}
    }

    final deliveryLat = widget.dispatch.deliveryLatitude;
    final deliveryLng = widget.dispatch.deliveryLongitude;
    if (deliveryLat != null && deliveryLng != null) {
      setState(() => _deliveryPointLatLng = LatLng(deliveryLat, deliveryLng));
    } else if (widget.dispatch.destinationAddress case final dest?
        when dest.isNotEmpty) {
      final ll = await _geocode(dest);
      if (ll != null && mounted) setState(() => _deliveryPointLatLng = ll);
    }
    if (mounted) {
      _fitBounds();
      _updateApproxDistance();
    }
  }

  Future<LatLng?> _geocode(String address) async {
    final queries = <String>[
      address,
      address.replaceFirst(RegExp(r'^[^,]+,\s*(?:[^,]+,\s*)?'), ''),
      RegExp(r'[A-Za-z\s]+\d{6}').firstMatch(address)?.group(0)?.trim() ?? '',
    ].where((q) => q.length > 4).toList();

    for (final q in queries) {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final resp = await Dio().get<List<dynamic>>(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': q,
            'format': 'json',
            'limit': '1',
            'countrycodes': 'in',
          },
          options: Options(
            headers: {
              'User-Agent': 'GreenRoot/1.0 (support@greenroot.in)',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final results = resp.data;
        if (results != null && results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          return LatLng(
            double.parse(r['lat'] as String),
            double.parse(r['lon'] as String),
          );
        }
      } catch (_) {}
    }
    return null;
  }

  void _updateApproxDistance() {
    final truck = _truckLatLng;
    final dest = _deliveryPointLatLng;
    if (truck == null || dest == null) return;
    const calc = Distance();
    final km = calc.as(LengthUnit.Kilometer, truck, dest);
    if (!mounted) return;
    setState(() => _approxDistanceKm = km);
    _fitBounds();
  }

  // ── Map helpers ──────────────────────────────────────────────────────────────

  void _onMapReady() {
    _mapReady = true;
    _fitBounds();
  }

  LatLng? get _truckLatLng => _trackingPts.isNotEmpty
      ? LatLng(_trackingPts.first.latitude, _trackingPts.first.longitude)
      : null;

  void _fitBounds() {
    if (!_mapReady || !mounted) return;
    final points = <LatLng>[
      if (_truckLatLng != null) _truckLatLng!,
      if (_loadingPointLatLng != null) _loadingPointLatLng!,
      if (_deliveryPointLatLng != null) _deliveryPointLatLng!,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    final minLat = points.map((p) => p.latitude).reduce(min);
    final maxLat = points.map((p) => p.latitude).reduce(max);
    final minLng = points.map((p) => p.longitude).reduce(min);
    final maxLng = points.map((p) => p.longitude).reduce(max);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        // Extra bottom padding so markers aren't hidden behind the floating card
        padding:
            const EdgeInsets.only(top: 100, left: 40, right: 40, bottom: 260),
      ),
    );
  }

  Future<void> _openInMaps() async {
    final addr = widget.dispatch.destinationAddress ?? '';
    if (addr.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.dispatch;
    final truck = _truckLatLng;
    final caps = ref.watch(sessionProvider).capabilities;
    final isOwnerView = caps.isNurseryOwner == true || caps.isManager == true;

    // Map controls must clear the collapsed bottom sheet (≈ 12% of screen height).
    final controlsBottom = MediaQuery.of(context).size.height * 0.12 + 16;

    return Stack(
      children: [
        // Full-screen map
        Positioned.fill(
          child: _FullMapSection(
            mapController: _mapController,
            truckLatLng: truck,
            loadingPointLatLng: isOwnerView ? _loadingPointLatLng : null,
            deliveryPointLatLng: _deliveryPointLatLng,
            trackingPts: _trackingPts,
            nurseryName: _nurseryName ?? 'Nursery',
            isInTransit: d.status == 'IN_TRANSIT',
            onMapReady: _onMapReady,
          ),
        ),

        // Top overlay: back + dispatch code chip + refresh
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopOverlay(
            dispatch: d,
            onRefresh: () {
              ref.invalidate(dispatchDetailProvider(widget.dispatchId));
              _loadTracking();
              _fetchNurseryAndGeocode();
            },
          ),
        ),

        // Status + distance chips
        Positioned(
          bottom: controlsBottom,
          left: 12,
          child: _StatusChipRow(
            status: d.status,
            hasPosition: truck != null,
            approxDistanceKm: _approxDistanceKm,
          ),
        ),

        // Center-on-truck button
        if (truck != null)
          Positioned(
            bottom: controlsBottom,
            right: 12,
            child: MapIconButton(
              icon: Icons.gps_fixed_rounded,
              onTap: () => _mapController.move(truck, 15),
            ),
          ),

        // Floating bottom card
        DraggableScrollableSheet(
          initialChildSize: 0.38,
          minChildSize: 0.12,
          maxChildSize: 0.88,
          snap: true,
          snapSizes: const [0.12, 0.38, 0.88],
          builder: (ctx, scrollCtrl) => _FloatingCard(
            scrollController: scrollCtrl,
            dispatch: d,
            approxDistanceKm: _approxDistanceKm,
            lastLocationAt: _lastLocationAt,
            isLive: _isLive,
            journeyExpanded: _journeyExpanded,
            plantsExpanded: _plantsExpanded,
            onJourneyToggle: () =>
                setState(() => _journeyExpanded = !_journeyExpanded),
            onPlantsToggle: () =>
                setState(() => _plantsExpanded = !_plantsExpanded),
            onOpenMaps: _openInMaps,
            onRefresh: () async {
              ref.invalidate(dispatchDetailProvider(widget.dispatchId));
              await _loadTracking();
              await _fetchNurseryAndGeocode();
            },
          ),
        ),
      ],
    );
  }
}

// ── Full-screen map ────────────────────────────────────────────────────────────

class _FullMapSection extends StatelessWidget {
  final MapController mapController;
  final LatLng? truckLatLng;
  final LatLng? loadingPointLatLng;
  final LatLng? deliveryPointLatLng;
  final List<TrackingPoint> trackingPts;
  final String nurseryName;
  final bool isInTransit;
  final VoidCallback onMapReady;

  const _FullMapSection({
    required this.mapController,
    required this.truckLatLng,
    required this.loadingPointLatLng,
    required this.deliveryPointLatLng,
    required this.trackingPts,
    required this.nurseryName,
    required this.isInTransit,
    required this.onMapReady,
  });

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(20.5937, 78.9629);
    final center = truckLatLng ??
        loadingPointLatLng ??
        deliveryPointLatLng ??
        defaultCenter;
    final zoom = truckLatLng != null ? 13.0 : 6.0;

    final gpsPts = trackingPts.reversed
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final routeLine = <LatLng>[
      if (truckLatLng != null) truckLatLng!,
      if (deliveryPointLatLng != null) deliveryPointLatLng!,
    ];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onMapReady: onMapReady,
      ),
      children: [
        ColorFiltered(
          colorFilter: kMapDesatFilter,
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'in.greenroot.greenroot_mobile',
          ),
        ),
        // Dotted route line: truck → delivery
        if (routeLine.length == 2)
          PolylineLayer(polylines: [
            Polyline(
              points: routeLine,
              strokeWidth: 5,
              color: AppColors.primaryMain.withValues(alpha: 0.50),
              pattern: const StrokePattern.dotted(spacingFactor: 2.5),
            ),
          ]),
        // GPS breadcrumb trail
        if (gpsPts.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: gpsPts,
              strokeWidth: 3.5,
              color: AppColors.primaryMain.withValues(alpha: 0.75),
            ),
          ]),
        MarkerLayer(markers: [
          // Loading / origin point — only shown for owner/manager
          if (loadingPointLatLng != null)
            Marker(
              point: loadingPointLatLng!,
              width: 76,
              height: 82,
              alignment: Alignment.topCenter,
              child: MapPointMarker(
                color: AppColors.forest600,
                label: nurseryName.length > 14
                    ? '${nurseryName.substring(0, 12)}…'
                    : nurseryName,
                sublabel: 'Origin',
                isNursery: true,
              ),
            ),
          // Delivery / home point
          if (deliveryPointLatLng != null)
            Marker(
              point: deliveryPointLatLng!,
              width: 76,
              height: 82,
              alignment: Alignment.topCenter,
              child: const MapPointMarker(
                color: AppColors.blue600,
                label: 'Your Address',
                sublabel: 'Delivery',
                isNursery: false,
              ),
            ),
          // Truck — pulses when IN_TRANSIT
          if (truckLatLng != null)
            Marker(
              point: truckLatLng!,
              width: 62,
              height: 62,
              child: MapTruckMarker(active: isInTransit),
            ),
        ]),
      ],
    );
  }
}

// ── Top overlay (frosted glass back + badge + refresh) ─────────────────────────

class _TopOverlay extends StatelessWidget {
  final Dispatch dispatch;
  final VoidCallback onRefresh;
  const _TopOverlay({required this.dispatch, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            MapIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: MapTextChip(
                  label: dispatch.dispatchCode,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            MapIconButton(
              icon: Icons.refresh_rounded,
              onTap: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status + distance chip row (bottom-left, above sheet) ─────────────────────

class _StatusChipRow extends StatelessWidget {
  final String status;
  final bool hasPosition;
  final double? approxDistanceKm;

  const _StatusChipRow({
    required this.status,
    required this.hasPosition,
    this.approxDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    if (s == 'IN_TRANSIT' && hasPosition) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MapTextChip(
            label: 'Live Tracking',
            color: AppColors.primaryMain,
            dot: true,
          ),
          if (approxDistanceKm != null) ...[
            const SizedBox(width: 6),
            MapChip(
              icon: Icons.straighten_rounded,
              label: _formatDistance(approxDistanceKm!),
              iconColor: AppColors.blue600,
            ),
          ],
        ],
      );
    }
    if (s == 'IN_TRANSIT') {
      return const MapTextChip(
          label: 'Awaiting Location', color: AppColors.amber700);
    }
    if (s == 'DISPATCHED') {
      return const MapTextChip(
          label: 'Out for Delivery', color: AppColors.blue600);
    }
    return const SizedBox.shrink();
  }
}

// ── Floating bottom card (Swiggy-style draggable sheet) ───────────────────────

class _FloatingCard extends StatelessWidget {
  final ScrollController scrollController;
  final Dispatch dispatch;
  final double? approxDistanceKm;
  final DateTime? lastLocationAt;
  final bool isLive;
  final bool journeyExpanded;
  final bool plantsExpanded;
  final VoidCallback onJourneyToggle;
  final VoidCallback onPlantsToggle;
  final VoidCallback onOpenMaps;
  final Future<void> Function() onRefresh;

  const _FloatingCard({
    required this.scrollController,
    required this.dispatch,
    required this.isLive,
    required this.journeyExpanded,
    required this.plantsExpanded,
    required this.onJourneyToggle,
    required this.onPlantsToggle,
    required this.onOpenMaps,
    required this.onRefresh,
    this.approxDistanceKm,
    this.lastLocationAt,
  });

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final hasAddr = d.destinationAddress?.isNotEmpty == true;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: RefreshIndicator(
        color: AppColors.primaryMain,
        onRefresh: onRefresh,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Driver info
            _DriverInfoCard(
              dispatch: d,
              lastLocationAt: lastLocationAt,
              approxDistanceKm: approxDistanceKm,
            ),
            const SizedBox(height: 12),

            // Delivery status timeline
            _BuyerJourneyCard(
              dispatch: d,
              expanded: journeyExpanded,
              onToggle: onJourneyToggle,
            ),

            // Plants in delivery
            if (d.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PlantsCard(
                items: d.items,
                expanded: plantsExpanded,
                onToggle: onPlantsToggle,
              ),
            ],

            // Open delivery address in Maps
            if (hasAddr) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: onOpenMaps,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open Delivery Address in Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue600,
                    side: const BorderSide(color: AppColors.blue600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            // Live tracking notice
            if (isLive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryMain, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lastLocationAt != null
                        ? 'Tracking active · updated ${_ago(lastLocationAt!)}'
                        : 'Tracking active · loading location…',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Driver info card ───────────────────────────────────────────────────────────

class _DriverInfoCard extends StatelessWidget {
  final Dispatch dispatch;
  final DateTime? lastLocationAt;
  final double? approxDistanceKm;

  const _DriverInfoCard({
    required this.dispatch,
    this.lastLocationAt,
    this.approxDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final display = LifecyclePresenter.forDispatch(
      dispatch: d,
      role: LifecycleRole.buyer,
    );
    final hasDriver = d.driverName?.isNotEmpty == true;
    final hasVehicle = d.vehicleNumber?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: AppColors.primaryMain, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDriver ? d.driverName! : 'Driver Assigned',
                  style: AppTypography.h4,
                ),
                if (hasVehicle) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        d.vehicleNumber!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  display.label,
                  style: AppTypography.caption.copyWith(
                    color: display.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (lastLocationAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Location updated ${_ago(lastLocationAt!)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          if (approxDistanceKm != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.straighten_rounded,
                    size: 16, color: AppColors.blue600),
                const SizedBox(height: 2),
                Text(
                  _formatDistance(approxDistanceKm!),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.end,
                ),
                Text(
                  'remaining',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Journey card (buyer-perspective timeline) ──────────────────────────────────

class _BuyerJourneyCard extends StatelessWidget {
  final Dispatch dispatch;
  final bool expanded;
  final VoidCallback onToggle;

  const _BuyerJourneyCard({
    required this.dispatch,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.route_rounded,
                        color: AppColors.primaryMain, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Delivery Status', style: AppTypography.h4),
                        Text(
                          'Track your delivery progress',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _BuyerTimeline(status: dispatch.status),
            ),
            InkWell(
              onTap: onToggle,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hide Status',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_up_rounded,
                        color: AppColors.primaryMain, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Buyer timeline ─────────────────────────────────────────────────────────────

enum _StepState { completed, active, pending }

class _BuyerStep {
  final int number;
  final String title;
  final String subtitle;
  final _StepState state;
  const _BuyerStep(
      {required this.number,
      required this.title,
      required this.subtitle,
      required this.state});
}

class _BuyerTimeline extends StatelessWidget {
  final String status;
  const _BuyerTimeline({required this.status});

  List<_BuyerStep> _buildSteps() {
    final completedUpTo = switch (status) {
      'PENDING' || 'PENDING_ACCEPTANCE' => 0,
      'ACCEPTED' => 1,
      'DISPATCHED' => 2,
      'IN_TRANSIT' => 3,
      'DELIVERED' => 5,
      _ => 0,
    };
    final activeStep = switch (status) {
      'PENDING' || 'PENDING_ACCEPTANCE' => 1,
      'ACCEPTED' => 2,
      'DISPATCHED' => 3,
      'IN_TRANSIT' => 4,
      'DELIVERED' || 'CANCELLED' => 0,
      _ => 1,
    };

    final defs = [
      (1, 'Dispatch Created', 'Your order is being prepared for shipment'),
      (2, 'Driver Assigned', 'A driver has been assigned to your delivery'),
      (3, 'Plants Loaded', 'Your plants are loaded and ready to ship'),
      (4, 'On the Way', 'Driver is en route to your delivery address'),
      (5, 'Delivered', 'Your order has been successfully delivered'),
    ];

    return defs.map((d) {
      final (num, title, sub) = d;
      final stepState = num <= completedUpTo
          ? _StepState.completed
          : num == activeStep
              ? _StepState.active
              : _StepState.pending;
      return _BuyerStep(
          number: num, title: title, subtitle: sub, state: stepState);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Column(
      children: steps.asMap().entries.map((e) {
        return _BuyerStepRow(step: e.value, isLast: e.key == steps.length - 1);
      }).toList(),
    );
  }
}

class _BuyerStepRow extends StatelessWidget {
  final _BuyerStep step;
  final bool isLast;
  const _BuyerStepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (circleBg, circleText, labelColor) = switch (step.state) {
      _StepState.completed => (
          AppColors.primaryMain,
          Colors.white,
          AppColors.textPrimary
        ),
      _StepState.active => (AppColors.blue600, Colors.white, AppColors.blue600),
      _StepState.pending => (
          AppColors.border,
          AppColors.textMuted,
          AppColors.textMuted
        ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration:
                      BoxDecoration(color: circleBg, shape: BoxShape.circle),
                  child: Center(
                    child: step.state == _StepState.completed
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : Text(
                            '${step.number}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: circleText,
                              fontFamily: 'Inter',
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.state == _StepState.completed
                          ? AppColors.primaryMain
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    step.title,
                    style: AppTypography.body.copyWith(
                      fontWeight: step.state == _StepState.active
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  Text(
                    step.subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plants card ────────────────────────────────────────────────────────────────

class _PlantsCard extends StatelessWidget {
  final List<DispatchItem> items;
  final bool expanded;
  final VoidCallback onToggle;

  const _PlantsCard(
      {required this.items, required this.expanded, required this.onToggle});

  int get _totalQty => items.fold(0, (sum, i) => sum + i.quantity.toInt());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: AppColors.primaryMain, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plants in this Delivery (${items.length})',
                          style: AppTypography.h4,
                        ),
                        Text(
                          'Total qty: $_totalQty',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            ...items.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              return Column(
                children: [
                  if (!isFirst) const Divider(height: 1, indent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardPadding,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.forest100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.spa_rounded,
                              color: AppColors.primaryMain, size: 16),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            e.value.plantName ?? 'Plant ${e.key + 1}',
                            style: AppTypography.body,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.forest100,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Qty ${e.value.quantity.toInt()}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryMain,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Could not load delivery',
              style: AppTypography.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }
}
