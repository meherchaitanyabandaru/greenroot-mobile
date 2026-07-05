import 'dart:async';
import 'dart:math' show min, max;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_badge.dart';
import '../dispatches/dispatches.dart';
import '../tracking/tracking.dart';

// ── Screen shell ───────────────────────────────────────────────────────────────

class BuyerDeliveryTrackingScreen extends ConsumerWidget {
  final int dispatchId;
  const BuyerDeliveryTrackingScreen({super.key, required this.dispatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dispatchDetailProvider(dispatchId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: async.maybeWhen(
          data: (d) => _AppBarTitle(dispatch: d),
          orElse: () => const Text('Track Delivery', style: AppTypography.h4),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.invalidate(dispatchDetailProvider(dispatchId)),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
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

// ── App bar title ──────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  final Dispatch dispatch;
  const _AppBarTitle({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dispatch.dispatchCode, style: AppTypography.h4),
              Text(
                dispatch.orderNumber != null
                    ? 'Order ${dispatch.orderNumber}'
                    : 'Your Delivery',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        StatusBadge(
          label: dispatch.status.replaceAll('_', ' '),
          variant: badgeVariantFromStatus(dispatch.status),
          dot: true,
        ),
        const SizedBox(width: 8),
      ],
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
  bool _journeyExpanded = true;
  bool _plantsExpanded = false;
  Timer? _pollTimer;
  DateTime? _lastRefresh;

  // Route + ETA
  List<LatLng> _routePoints = [];
  int? _etaMinutes;
  double? _distToDestKm;

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

  bool get _isCompleted =>
      widget.dispatch.status == 'DELIVERED' ||
      widget.dispatch.status == 'CANCELLED';

  // ── Data fetching ────────────────────────────────────────────────────────────

  Future<void> _loadTracking({bool silent = false}) async {
    try {
      final pts = await ref
          .read(trackingRepositoryProvider)
          .getDispatchTracking(widget.dispatchId);
      if (mounted) {
        setState(() {
          _trackingPts = pts;
          _lastRefresh = DateTime.now();
        });
        if (pts.isNotEmpty && _mapReady) _fitBounds();
        _fetchRoute();
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

    final dest = widget.dispatch.destinationAddress;
    if (dest != null && dest.isNotEmpty) {
      final ll = await _geocode(dest);
      if (ll != null && mounted) setState(() => _deliveryPointLatLng = ll);
    }
    if (mounted) {
      _fitBounds();
      _fetchRoute();
    }
  }

  Future<LatLng?> _geocode(String address) async {
    // Try progressively simpler queries so apartment-level addresses still resolve.
    final queries = <String>[
      address,
      // Drop "Flat 12B, Building name," prefix — keep area + city + pin
      address.replaceFirst(RegExp(r'^[^,]+,\s*(?:[^,]+,\s*)?'), ''),
      // Just pincode + city
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

  // ── Route + ETA from OSRM ────────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    final truck = _truckLatLng;
    final dest = _deliveryPointLatLng;
    if (truck == null || dest == null) return;
    try {
      final resp = await Dio().get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving'
        '/${truck.longitude},${truck.latitude};${dest.longitude},${dest.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
        options: Options(
          headers: {'User-Agent': 'GreenRoot-Buyer/1.0'},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = resp.data!;
      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return;
      final route = routes.first as Map<String, dynamic>;
      final secs = (route['duration'] as num).toDouble();
      final meters = (route['distance'] as num).toDouble();
      final pts = (route['geometry']['coordinates'] as List<dynamic>)
          .map((c) {
            final arr = c as List<dynamic>;
            return LatLng(
                (arr[1] as num).toDouble(), (arr[0] as num).toDouble());
          })
          .toList();
      if (mounted) {
        setState(() {
          _routePoints = pts;
          _etaMinutes = (secs / 60).ceil();
          _distToDestKm = meters / 1000;
        });
        _fitBounds();
      }
    } catch (_) {
      // Straight-line fallback when OSRM is unreachable
      if (mounted) {
        const calc = Distance();
        setState(() {
          _distToDestKm = calc.as(LengthUnit.Kilometer, truck, dest);
        });
        _fitBounds();
      }
    }
  }

  // ── Map helpers ──────────────────────────────────────────────────────────────

  void _onMapReady() {
    _mapReady = true;
    _fitBounds();
  }

  LatLng? get _truckLatLng => _trackingPts.isNotEmpty
      ? LatLng(_trackingPts.last.latitude, _trackingPts.last.longitude)
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
        padding: const EdgeInsets.all(64),
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

    return Column(
      children: [
        // Map — visible for live dispatches only
        if (!_isCompleted && _isLive) ...[
          _MapSection(
            mapController: _mapController,
            truckLatLng: truck,
            loadingPointLatLng: _loadingPointLatLng,
            deliveryPointLatLng: _deliveryPointLatLng,
            trackingPts: _trackingPts,
            routePoints: _routePoints,
            nurseryName: _nurseryName ?? 'Nursery',
            isInTransit: d.status == 'IN_TRANSIT',
            distToDestKm: _distToDestKm,
            etaMinutes: _etaMinutes,
            onMapReady: _onMapReady,
            onCenterTruck: truck == null
                ? null
                : () => _mapController.move(truck, 15),
          ),
          _LegendStrip(
            hasTruck: truck != null,
            hasLoading: _loadingPointLatLng != null,
            hasDelivery: _deliveryPointLatLng != null,
          ),
          if (truck != null && (_etaMinutes != null || _distToDestKm != null))
            _EtaStrip(etaMinutes: _etaMinutes, distKm: _distToDestKm),
        ],

        // Scrollable content
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryMain,
            onRefresh: () async {
              ref.invalidate(dispatchDetailProvider(widget.dispatchId));
              await _loadTracking();
              await _fetchNurseryAndGeocode();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  _DriverInfoCard(dispatch: d, lastRefresh: _lastRefresh),
                  const SizedBox(height: AppSpacing.md),
                  _BuyerJourneyCard(
                    dispatch: d,
                    expanded: _journeyExpanded,
                    onToggle: () =>
                        setState(() => _journeyExpanded = !_journeyExpanded),
                  ),
                  if (d.items.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PlantsCard(
                      items: d.items,
                      expanded: _plantsExpanded,
                      onToggle: () =>
                          setState(() => _plantsExpanded = !_plantsExpanded),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),

        // Bottom bar
        _BuyerBottomBar(
          destinationAddress: d.destinationAddress,
          isLive: _isLive,
          lastRefresh: _lastRefresh,
          onOpenMaps: _openInMaps,
        ),
      ],
    );
  }
}

// ── Map section ────────────────────────────────────────────────────────────────

class _MapSection extends StatelessWidget {
  final MapController mapController;
  final LatLng? truckLatLng;
  final LatLng? loadingPointLatLng;
  final LatLng? deliveryPointLatLng;
  final List<TrackingPoint> trackingPts;
  final List<LatLng> routePoints;
  final String nurseryName;
  final bool isInTransit;
  final double? distToDestKm;
  final int? etaMinutes;
  final VoidCallback onMapReady;
  final VoidCallback? onCenterTruck;

  const _MapSection({
    required this.mapController,
    required this.truckLatLng,
    required this.loadingPointLatLng,
    required this.deliveryPointLatLng,
    required this.trackingPts,
    required this.routePoints,
    required this.nurseryName,
    required this.isInTransit,
    required this.onMapReady,
    this.distToDestKm,
    this.etaMinutes,
    this.onCenterTruck,
  });

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(20.5937, 78.9629);
    final center = truckLatLng ??
        loadingPointLatLng ??
        deliveryPointLatLng ??
        defaultCenter;
    final zoom = truckLatLng != null ? 13.0 : 6.0;

    final gpsPts =
        trackingPts.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final straightLine = <LatLng>[
      if (truckLatLng != null) truckLatLng!,
      if (deliveryPointLatLng != null) deliveryPointLatLng!,
    ];

    return SizedBox(
      height: 310,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              onMapReady: onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.greenroot.greenroot_mobile',
              ),
              // Straight-line fallback (visible immediately, replaced by OSRM when ready)
              if (routePoints.isEmpty && straightLine.length == 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: straightLine,
                      strokeWidth: 2.5,
                      color: AppColors.primaryMain.withValues(alpha: 0.45),
                      pattern: const StrokePattern.dotted(spacingFactor: 3),
                    ),
                  ],
                ),
              // Road route driver → destination (OSRM — replaces straight line)
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 6,
                      color: AppColors.primaryMain.withValues(alpha: 0.25),
                    ),
                    Polyline(
                      points: routePoints,
                      strokeWidth: 3.5,
                      color: AppColors.primaryMain,
                    ),
                  ],
                ),
              // Breadcrumb trail (GPS history) — thinner, muted
              if (gpsPts.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: gpsPts,
                      strokeWidth: 2,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (loadingPointLatLng != null)
                    Marker(
                      point: loadingPointLatLng!,
                      width: 56,
                      height: 72,
                      alignment: Alignment.topCenter,
                      child: _MapMarker(
                        color: AppColors.amber600,
                        icon: Icons.store_rounded,
                        label: nurseryName.length > 14
                            ? '${nurseryName.substring(0, 12)}…'
                            : nurseryName,
                        sublabel: 'Origin',
                      ),
                    ),
                  if (deliveryPointLatLng != null)
                    Marker(
                      point: deliveryPointLatLng!,
                      width: 72,
                      height: 72,
                      alignment: Alignment.topCenter,
                      child: const _MapMarker(
                        color: AppColors.blue600,
                        icon: Icons.home_rounded,
                        label: 'Your',
                        sublabel: 'Location',
                      ),
                    ),
                  if (truckLatLng != null)
                    Marker(
                      point: truckLatLng!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryMain.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_shipping_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Live / awaiting chip
          Positioned(
            top: 8,
            left: 8,
            child: _LiveChip(
              isInTransit: isInTransit,
              hasPosition: truckLatLng != null,
            ),
          ),

          // Distance + ETA pills (bottom-left)
          if (distToDestKm != null || etaMinutes != null)
            Positioned(
              bottom: 8,
              left: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distToDestKm != null)
                    _MapPill(
                      icon: Icons.straighten_rounded,
                      color: AppColors.blue600,
                      label: distToDestKm! < 1
                          ? '${(distToDestKm! * 1000).toStringAsFixed(0)} m'
                          : '${distToDestKm!.toStringAsFixed(1)} km',
                    ),
                  if (distToDestKm != null && etaMinutes != null)
                    const SizedBox(width: 6),
                  if (etaMinutes != null)
                    _MapPill(
                      icon: Icons.access_time_rounded,
                      color: AppColors.primaryMain,
                      label: etaMinutes! < 60
                          ? '~$etaMinutes min'
                          : '~${(etaMinutes! / 60).toStringAsFixed(1)} hr',
                    ),
                ],
              ),
            ),

          // Center-on-truck button
          if (onCenterTruck != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: onCenterTruck,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6),
                    ],
                  ),
                  child: const Icon(Icons.gps_fixed_rounded,
                      color: AppColors.primaryMain, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Map marker with label ──────────────────────────────────────────────────────

class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String sublabel;

  const _MapMarker({
    required this.color,
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 3),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: 'Inter'),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sublabel,
                style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.textMuted,
                    fontFamily: 'Inter'),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Live chip ──────────────────────────────────────────────────────────────────

class _LiveChip extends StatelessWidget {
  final bool isInTransit;
  final bool hasPosition;

  const _LiveChip({required this.isInTransit, required this.hasPosition});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = isInTransit && hasPosition
        ? (AppColors.primaryLight, AppColors.primaryMain, 'Live Tracking')
        : isInTransit
            ? (
                AppColors.amber100,
                AppColors.amber700,
                'Awaiting Location'
              )
            : (AppColors.blue100, AppColors.blue600, 'Loading Plants');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isInTransit && hasPosition)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            )
          else
            Icon(
              isInTransit
                  ? Icons.location_searching_rounded
                  : Icons.inventory_2_outlined,
              size: 11,
              color: fg,
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
                fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}

// ── Small map overlay pill ─────────────────────────────────────────────────────

class _MapPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _MapPill({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 5),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

// ── ETA strip (below legend) ───────────────────────────────────────────────────

class _EtaStrip extends StatelessWidget {
  final int? etaMinutes;
  final double? distKm;
  const _EtaStrip({this.etaMinutes, this.distKm});

  @override
  Widget build(BuildContext context) {
    final etaStr = etaMinutes == null
        ? null
        : etaMinutes! < 60
            ? '~$etaMinutes min'
            : '~${(etaMinutes! / 60).toStringAsFixed(1)} hr';
    final distStr = distKm == null
        ? null
        : distKm! < 1
            ? '${(distKm! * 1000).toStringAsFixed(0)} m away'
            : '${distKm!.toStringAsFixed(1)} km away';

    return Container(
      color: AppColors.primaryMain,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (etaStr != null)
                  Text(
                    'Arrives in $etaStr',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                if (distStr != null)
                  Text(
                    'Driver is $distStr',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFamily: 'Inter',
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.local_shipping_rounded,
              color: Colors.white, size: 22),
        ],
      ),
    );
  }
}

// ── Legend strip ───────────────────────────────────────────────────────────────

class _LegendStrip extends StatelessWidget {
  final bool hasTruck;
  final bool hasLoading;
  final bool hasDelivery;

  const _LegendStrip({
    required this.hasTruck,
    required this.hasLoading,
    required this.hasDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(
            icon: Icons.local_shipping_rounded,
            color: AppColors.primaryMain,
            label: 'Driver',
            active: hasTruck,
          ),
          Container(width: 1, height: 24, color: AppColors.border),
          _LegendItem(
            icon: Icons.store_rounded,
            color: AppColors.amber600,
            label: 'From Nursery',
            active: hasLoading,
          ),
          Container(width: 1, height: 24, color: AppColors.border),
          _LegendItem(
            icon: Icons.home_rounded,
            color: AppColors.blue600,
            label: 'Your Address',
            active: hasDelivery,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool active;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final c = active ? color : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c, size: 15),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ── Driver info card ───────────────────────────────────────────────────────────

class _DriverInfoCard extends StatelessWidget {
  final Dispatch dispatch;
  final DateTime? lastRefresh;

  const _DriverInfoCard({required this.dispatch, this.lastRefresh});

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final hasDriver = d.driverName?.isNotEmpty == true;
    final hasVehicle = d.vehicleNumber?.isNotEmpty == true;
    final hasAddr = d.destinationAddress?.isNotEmpty == true;

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
                if (lastRefresh != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Location updated ${_ago(lastRefresh!)}',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          if (hasAddr) ...[
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.blue600),
                const SizedBox(height: 2),
                SizedBox(
                  width: 90,
                  child: Text(
                    d.destinationAddress!,
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
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
    if (diff.inMinutes < 1) return 'just now';
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
      _StepState.active => (
          AppColors.blue600,
          Colors.white,
          AppColors.blue600
        ),
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

// ── Bottom action bar ──────────────────────────────────────────────────────────

class _BuyerBottomBar extends StatelessWidget {
  final String? destinationAddress;
  final bool isLive;
  final DateTime? lastRefresh;
  final VoidCallback onOpenMaps;

  const _BuyerBottomBar({
    required this.destinationAddress,
    required this.isLive,
    required this.lastRefresh,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddr = destinationAddress?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
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
                  lastRefresh != null
                      ? 'Tracking active · updated ${_ago(lastRefresh!)}'
                      : 'Tracking active · loading location…',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (hasAddr)
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
      ),
    );
  }

  static String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
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
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }
}
