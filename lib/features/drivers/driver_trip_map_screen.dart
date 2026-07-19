import 'dart:async';
import 'dart:math' show min, max;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/status_badge.dart';
import '../dispatches/dispatches.dart';
import '../orders/orders.dart';
import '../tracking/tracking.dart';

// ── Screen shell ───────────────────────────────────────────────────────────────

class DriverTripMapScreen extends ConsumerWidget {
  final int dispatchId;
  const DriverTripMapScreen({super.key, required this.dispatchId});

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
          orElse: () => const Text('Trip Details', style: AppTypography.h4),
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
        data: (dispatch) => DriverTripMapBody(
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
    final display = LifecyclePresenter.forDispatchStatus(dispatch.status);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dispatch.dispatchCode, style: AppTypography.h4),
              Row(
                children: [
                  Text(
                    'Trip Code',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: dispatch.dispatchCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trip code copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded,
                        size: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        StatusBadge(
          label: display.label,
          variant: display.variant,
          dot: true,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ── Stateful body ──────────────────────────────────────────────────────────────

class DriverTripMapBody extends ConsumerStatefulWidget {
  final Dispatch dispatch;
  final int dispatchId;
  const DriverTripMapBody(
      {super.key, required this.dispatch, required this.dispatchId});

  @override
  ConsumerState<DriverTripMapBody> createState() => DriverTripMapBodyState();
}

class DriverTripMapBodyState extends ConsumerState<DriverTripMapBody> {
  final _mapController = MapController();

  // GPS
  Position? _devicePos;
  bool _locationGranted = false;
  Timer? _gpsTimer;
  bool _postingGps = false;

  // Geocoded markers
  LatLng? _loadingPointLatLng;
  LatLng? _deliveryPointLatLng;
  String? _nurseryName;

  // Tracking history
  List<TrackingPoint> _trackingPts = [];

  // UI state — timeline starts collapsed so the map is the focus
  bool _journeyExpanded = false;
  bool _plantsExpanded = false;
  bool _busy = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    if (_usesLiveMap(widget.dispatch.status)) {
      _initGps();
      _fetchNurseryAndGeocode();
    }
    if (widget.dispatch.status == 'IN_TRANSIT') {
      _startGpsPosting();
      _loadTracking();
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _initGps() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (!mounted) return;
    setState(() {
      _devicePos = pos;
      _locationGranted = true;
    });
    _fitBounds();
  }

  void _startGpsPosting() {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _postGps());
  }

  Future<void> _postGps() async {
    if (_postingGps) return;
    _postingGps = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _devicePos = pos);
      final repo = ref.read(trackingRepositoryProvider);
      await Future.wait([
        repo.postLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          dispatchId: widget.dispatchId,
        ),
        repo
            .postLiveLocation(
              latitude: pos.latitude,
              longitude: pos.longitude,
              dispatchId: widget.dispatchId,
            )
            .catchError((_) {}),
      ]);
    } catch (_) {
    } finally {
      _postingGps = false;
    }
  }

  Future<void> _loadTracking() async {
    try {
      final pts = await ref
          .read(trackingRepositoryProvider)
          .getDispatchTracking(widget.dispatchId);
      if (mounted) setState(() => _trackingPts = pts);
    } catch (_) {}
  }

  bool _usesLiveMap(String status) =>
      status == 'DISPATCHED' || status == 'IN_TRANSIT';

  // True once loading at the nursery is complete and driver heads to delivery.
  bool get _loadingComplete {
    final ds = widget.dispatch.status.toUpperCase();
    final os = widget.dispatch.orderStatus?.toUpperCase();
    if (ds == 'DISPATCHED' || ds == 'IN_TRANSIT' || ds == 'DELIVERED') {
      return true;
    }
    if (ds == 'ACCEPTED' &&
        (os == 'LOADED' || os == 'PARTIALLY_FULFILLED' || os == 'COMPLETED')) {
      return true;
    }
    return false;
  }

  // Active destination: where the driver should go RIGHT NOW.
  LatLng? get _activeDestination =>
      _loadingComplete ? _deliveryPointLatLng : _loadingPointLatLng;

  void _onMapReady() {
    _mapReady = true;
    _fitBounds();
  }

  void _fitBounds() {
    if (!_mapReady || !mounted) return;
    // Fit only truck + active destination for a focused driver view.
    final dest = _activeDestination;
    final points = <LatLng>[
      if (_devicePos != null)
        LatLng(_devicePos!.latitude, _devicePos!.longitude),
      if (dest != null) dest,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
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

  // ── Nursery fetch + geocode ──────────────────────────────────────────────────

  Future<void> _fetchNurseryAndGeocode() async {
    final nurseryId = widget.dispatch.sellerNurseryId;
    if (nurseryId == null) return;

    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        '/api/v1/nurseries/$nurseryId',
      );
      final n = (data['nursery'] ?? data) as Map<String, dynamic>;
      final name = n['name'] as String? ?? 'Nursery';
      String? addr;
      final addresses = n['addresses'] as List<dynamic>?;
      if (addresses != null && addresses.isNotEmpty) {
        // prefer primary address
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
        if (ll != null && mounted) setState(() => _loadingPointLatLng = ll);
      }
    } catch (_) {}

    // Use delivery coords from API when available; fall back to geocoding
    final dlat = widget.dispatch.deliveryLatitude;
    final dlon = widget.dispatch.deliveryLongitude;
    if (dlat != null && dlon != null) {
      if (mounted) setState(() => _deliveryPointLatLng = LatLng(dlat, dlon));
    } else {
      final dest = widget.dispatch.destinationAddress;
      if (dest != null && dest.isNotEmpty) {
        final ll = await _geocode(dest);
        if (ll != null && mounted) setState(() => _deliveryPointLatLng = ll);
      }
    }
    if (mounted) _fitBounds();
  }

  Future<LatLng?> _geocode(String address) async {
    try {
      final resp = await Dio().get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': address, 'format': 'json', 'limit': '1'},
        options: Options(
          headers: {'User-Agent': 'GreenRoot-Driver/1.0'},
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final results = resp.data;
      if (results != null && results.isNotEmpty) {
        final r = results.first as Map<String, dynamic>;
        return LatLng(
            double.parse(r['lat'] as String), double.parse(r['lon'] as String));
      }
    } catch (_) {}
    return null;
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _acceptTrip() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .acceptDispatch(widget.dispatchId);
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
      ref.invalidate(activeDriverTripProvider);
      _snack('Trip accepted! Waiting for nursery to load plants.');
    } on AppError catch (e) {
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startJourney() async {
    if (widget.dispatch.status != 'DISPATCHED') {
      _snack('Cannot start — loading is not yet complete.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.dispatchId, 'IN_TRANSIT');
      _startGpsPosting();
      await _postGps();
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
      ref.invalidate(activeDriverTripProvider);
      _snack('Journey started! GPS tracking active.');
    } on AppError catch (e) {
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeDelivery() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete Delivery?'),
        content: const Text(
            'Make sure you have uploaded at least one delivery proof photo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.dispatchId, 'DELIVERED');
      _gpsTimer?.cancel();
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
      ref.invalidate(orderListProvider);
      ref.invalidate(buyingOrderListProvider);
      ref.invalidate(activeDriverTripProvider);
      _snack('Delivery completed. Well done!');
    } on AppError catch (e) {
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGoogleMaps() async {
    final dlat = widget.dispatch.deliveryLatitude;
    final dlon = widget.dispatch.deliveryLongitude;
    final addr = widget.dispatch.destinationAddress ?? '';
    if (dlat == null && addr.isEmpty) return;
    final query = dlat != null ? '$dlat,$dlon' : Uri.encodeComponent(addr);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Clipboard.setData(ClipboardData(text: addr));
      _snack('Address copied — paste into Google Maps.');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.red600 : AppColors.primaryMain,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.dispatch;

    final isDelivered = d.status == 'DELIVERED' || d.status == 'CANCELLED';
    final showMap = _usesLiveMap(d.status);

    double? distKm;
    if (showMap &&
        _loadingPointLatLng != null &&
        _deliveryPointLatLng != null) {
      const calc = Distance();
      distKm = calc.as(
          LengthUnit.Kilometer, _loadingPointLatLng!, _deliveryPointLatLng!);
    }

    return Column(
      children: [
        // ── Fixed map — hidden for completed/cancelled trips ───────────────────
        if (!isDelivered && showMap) ...[
          _MapSection(
            mapController: _mapController,
            devicePos: _devicePos,
            locationGranted: _locationGranted,
            loadingPointLatLng: _loadingPointLatLng,
            deliveryPointLatLng: _deliveryPointLatLng,
            trackingPts: _trackingPts,
            nurseryName: _nurseryName ?? 'Loading Point',
            deliveryAddress: d.destinationAddress ?? 'Delivery Point',
            isInTransit: d.status == 'IN_TRANSIT',
            loadingComplete: _loadingComplete,
            distanceKm: distKm,
            onMapReady: _onMapReady,
            onCenterTruck: _devicePos == null
                ? null
                : () => _mapController.move(
                      LatLng(_devicePos!.latitude, _devicePos!.longitude),
                      15,
                    ),
          ),
          _LegendStrip(
            hasTruck: _locationGranted,
            hasLoading: _loadingPointLatLng != null,
            hasDelivery: _deliveryPointLatLng != null,
          ),
        ],

        // ── Scrollable content ─────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryMain,
            onRefresh: () async {
              ref.invalidate(dispatchDetailProvider(widget.dispatchId));
              if (showMap) {
                await _initGps();
                await _fetchNurseryAndGeocode();
              }
              if (d.status == 'IN_TRANSIT') {
                await _loadTracking();
                await _postGps();
              }
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
                  // Order Journey timeline
                  _OrderJourneyCard(
                    status: d.status,
                    orderStatus: d.orderStatus,
                    createdAt: d.createdAt,
                    updatedAt: d.updatedAt,
                    loadingStartedAt: d.loadingStartedAt,
                    loadingCompletedAt: d.loadingCompletedAt,
                    expanded: _journeyExpanded,
                    onToggle: () =>
                        setState(() => _journeyExpanded = !_journeyExpanded),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Plants summary
                  if (d.items.isNotEmpty)
                    _PlantsCard(
                      items: d.items,
                      expanded: _plantsExpanded,
                      onToggle: () =>
                          setState(() => _plantsExpanded = !_plantsExpanded),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Sticky bottom action bar ───────────────────────────────────────────
        _BottomActionBar(
          status: d.status,
          busy: _busy,
          destinationAddress: d.destinationAddress,
          onAccept: _acceptTrip,
          onRefresh: () =>
              ref.invalidate(dispatchDetailProvider(widget.dispatchId)),
          onNavigate: _openGoogleMaps,
          onStartJourney: _startJourney,
          onAddEvent: () =>
              context.push('/driver/trips/${widget.dispatchId}/event'),
          onUploadProof: () =>
              context.push('/driver/trips/${widget.dispatchId}/proof'),
          onCompleteDelivery: _completeDelivery,
        ),
      ],
    );
  }
}

// ── Map section ────────────────────────────────────────────────────────────────

class _MapSection extends StatelessWidget {
  final MapController mapController;
  final Position? devicePos;
  final bool locationGranted;
  final LatLng? loadingPointLatLng;
  final LatLng? deliveryPointLatLng;
  final List<TrackingPoint> trackingPts;
  final String nurseryName;
  final String deliveryAddress;
  final bool isInTransit;
  final bool loadingComplete;
  final double? distanceKm;
  final VoidCallback onMapReady;
  final VoidCallback? onCenterTruck;

  const _MapSection({
    required this.mapController,
    required this.devicePos,
    required this.locationGranted,
    required this.loadingPointLatLng,
    required this.deliveryPointLatLng,
    required this.trackingPts,
    required this.nurseryName,
    required this.deliveryAddress,
    required this.isInTransit,
    required this.loadingComplete,
    required this.onMapReady,
    this.distanceKm,
    this.onCenterTruck,
  });

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(20.5937, 78.9629);
    final truckLatLng = devicePos != null
        ? LatLng(devicePos!.latitude, devicePos!.longitude)
        : null;
    final center = truckLatLng ??
        loadingPointLatLng ??
        deliveryPointLatLng ??
        defaultCenter;
    final zoom = truckLatLng != null ? 13.0 : 6.0;

    // Single active leg: truck → next destination only.
    // Before loading done: truck → loading point.
    // After loading done: truck → delivery point.
    final activeDestination =
        loadingComplete ? deliveryPointLatLng : loadingPointLatLng;

    final routePoints = <LatLng>[
      if (truckLatLng != null) truckLatLng,
      if (activeDestination != null) activeDestination,
    ];

    final gpsPts =
        trackingPts.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // ETA estimate based on straight-line distance at 30 km/h
    String? etaLabel;
    if (distanceKm != null && isInTransit) {
      final mins = (distanceKm! / 30 * 60).round();
      etaLabel = mins < 60 ? '~$mins min' : '~${mins ~/ 60}h ${mins % 60}m';
    }

    return SizedBox(
      height: 292,
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
              ColorFiltered(
                colorFilter: kMapDesatFilter,
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'in.greenroot.greenroot_mobile',
                ),
              ),

              // Active route — glow + main
              if (routePoints.length >= 2) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 16,
                      color: AppColors.primaryMain.withValues(alpha: 0.10),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: AppColors.primaryMain.withValues(alpha: 0.82),
                      pattern: isInTransit
                          ? const StrokePattern.dotted(spacingFactor: 2.5)
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),
              ],

              // GPS breadcrumb — solid driven path
              if (gpsPts.length >= 2) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: gpsPts,
                      strokeWidth: 16,
                      color: AppColors.primaryMain.withValues(alpha: 0.14),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: gpsPts,
                      strokeWidth: 5,
                      color: AppColors.primaryMain,
                    ),
                  ],
                ),
              ],

              MarkerLayer(
                markers: [
                  // Loading point — shown active before loading, dimmed after
                  if (loadingPointLatLng != null)
                    Marker(
                      point: loadingPointLatLng!,
                      width: loadingComplete ? 52 : 72,
                      height: loadingComplete ? 52 : 84,
                      alignment: Alignment.topCenter,
                      child: loadingComplete
                          ? const MapCompletedMarker(label: 'Loaded')
                          : MapPointMarker(
                              color: AppColors.forest600,
                              label: nurseryName.length > 14
                                  ? '${nurseryName.substring(0, 12)}…'
                                  : nurseryName,
                              sublabel: 'Loading Point',
                              isNursery: true,
                            ),
                    ),
                  // Delivery point — shown after loading is complete
                  if (deliveryPointLatLng != null && loadingComplete)
                    Marker(
                      point: deliveryPointLatLng!,
                      width: 72,
                      height: 84,
                      alignment: Alignment.topCenter,
                      child: const MapPointMarker(
                        color: AppColors.blue600,
                        label: 'Delivery',
                        sublabel: 'Point',
                        isNursery: false,
                      ),
                    ),
                  // Truck
                  if (truckLatLng != null)
                    Marker(
                      point: truckLatLng,
                      width: 62,
                      height: 62,
                      child: MapTruckMarker(active: isInTransit),
                    ),
                ],
              ),
            ],
          ),

          // GPS chip — top left
          Positioned(
            top: 10,
            left: 10,
            child: _GpsChip(granted: locationGranted, isPosting: isInTransit),
          ),

          // Center-on-truck — top right
          if (onCenterTruck != null)
            Positioned(
              top: 10,
              right: 10,
              child: MapIconButton(
                icon: Icons.my_location_rounded,
                onTap: onCenterTruck!,
              ),
            ),

          // Distance + ETA chips — bottom left
          Positioned(
            bottom: 10,
            left: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (distanceKm != null)
                  MapChip(
                    icon: Icons.straighten_rounded,
                    label: distanceKm! < 1
                        ? '${(distanceKm! * 1000).toStringAsFixed(0)} m'
                        : '${distanceKm!.toStringAsFixed(1)} km',
                    iconColor: AppColors.blue600,
                  ),
                if (etaLabel != null) ...[
                  const SizedBox(width: 6),
                  MapChip(
                    icon: Icons.schedule_rounded,
                    label: etaLabel,
                    iconColor: AppColors.amber600,
                  ),
                ],
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(
            color: AppColors.primaryMain,
            label: 'Your Truck',
            active: hasTruck,
          ),
          Container(width: 1, height: 20, color: AppColors.border),
          _LegendItem(
            color: AppColors.forest600,
            label: 'Loading Point',
            active: hasLoading,
          ),
          Container(width: 1, height: 20, color: AppColors.border),
          _LegendItem(
            color: AppColors.blue600,
            label: 'Delivery Point',
            active: hasDelivery,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool active;

  const _LegendItem({
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
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c,
            fontFamily: 'Inter',
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ── GPS chip — blurred pill with live pulsing dot when active ─────────────────

class _GpsChip extends StatefulWidget {
  final bool granted;
  final bool isPosting;
  const _GpsChip({required this.granted, required this.isPosting});

  @override
  State<_GpsChip> createState() => _GpsChipState();
}

class _GpsChipState extends State<_GpsChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _blink = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.granted && widget.isPosting) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_GpsChip old) {
    super.didUpdateWidget(old);
    if (widget.granted && widget.isPosting) {
      if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (fg, label) = !widget.granted
        ? (AppColors.amber700, 'GPS off')
        : widget.isPosting
            ? (AppColors.primaryMain, 'GPS Active')
            : (AppColors.primaryMid, 'GPS Ready');

    final dot = widget.granted && widget.isPosting;

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot)
                AnimatedBuilder(
                  animation: _blink,
                  builder: (_, __) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.45 + _blink.value * 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else ...[
                Icon(
                  widget.granted
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_off_rounded,
                  size: 11,
                  color: fg,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  fontFamily: 'Inter',
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order Journey card (collapsible timeline) ──────────────────────────────────

class _OrderJourneyCard extends StatelessWidget {
  final String status;
  final String? orderStatus;
  final String createdAt;
  final String? updatedAt;
  final String? loadingStartedAt;
  final String? loadingCompletedAt;
  final bool expanded;
  final VoidCallback onToggle;

  const _OrderJourneyCard({
    required this.status,
    this.orderStatus,
    required this.createdAt,
    this.updatedAt,
    this.loadingStartedAt,
    this.loadingCompletedAt,
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
          // Header row
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
                        const Text('Order Journey', style: AppTypography.h4),
                        Text(
                          'All steps of this order',
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

          // Timeline (visible when expanded)
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _JourneyTimeline(
                status: status,
                orderStatus: orderStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                loadingStartedAt: loadingStartedAt,
                loadingCompletedAt: loadingCompletedAt,
              ),
            ),
            // Hide button
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
                      'Hide Journey',
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

// ── Journey timeline ───────────────────────────────────────────────────────────

enum _StepState { completed, active, pending }

class _Step {
  final int number;
  final String title;
  final String subtitle;
  final _StepState state;
  final String? time;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.time,
  });
}

class _JourneyTimeline extends StatelessWidget {
  final String status;
  final String? orderStatus;
  final String createdAt;
  final String? updatedAt;
  final String? loadingStartedAt;
  final String? loadingCompletedAt;

  const _JourneyTimeline({
    required this.status,
    this.orderStatus,
    required this.createdAt,
    this.updatedAt,
    this.loadingStartedAt,
    this.loadingCompletedAt,
  });

  String _fmt(String? iso) {
    if (iso == null) return '--';
    try {
      return DateFormat('d MMM, h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '--';
    }
  }

  List<_Step> _buildSteps() {
    final created = _fmt(createdAt);
    final updated = _fmt(updatedAt ?? createdAt);
    final loadingStarted = _fmt(loadingStartedAt);
    final loadingCompleted = _fmt(loadingCompletedAt);
    final order = orderStatus?.toUpperCase();
    final dispatch = status.toUpperCase();

    var completedUpTo = switch (dispatch) {
      'PENDING' => 0,
      'ACCEPTED' => 1,
      'DISPATCHED' => 6,
      'IN_TRANSIT' => 7,
      'DELIVERED' => 11,
      _ => 0,
    };
    var activeStep = switch (dispatch) {
      'PENDING' => 1,
      'ACCEPTED' => 2,
      'DISPATCHED' => 7,
      'IN_TRANSIT' => 8,
      'DELIVERED' => 0,
      _ => 1,
    };

    if (dispatch == 'ACCEPTED') {
      switch (order) {
        case 'LOADING':
          completedUpTo = 3;
          activeStep = 4;
        case 'LOADED':
        case 'PARTIALLY_FULFILLED':
        case 'COMPLETED':
          completedUpTo = 5;
          activeStep = 6;
      }
    }

    String? timeFor(int step) {
      if (step == 1) return created;
      if (step == 2 && loadingStartedAt != null) return loadingStarted;
      if (step == 3 && loadingStartedAt != null) return loadingStarted;
      if (step == 5 && loadingCompletedAt != null) return loadingCompleted;
      if (step <= completedUpTo) return updated;
      return null;
    }

    final definitions = [
      (1, 'Trip Accepted', 'You accepted this trip'),
      (2, 'Waiting for Loading', 'Waiting for nursery to start loading'),
      (3, 'Loading Started', 'Loading has been started at nursery'),
      (4, 'Loading In Progress', 'Plants are being loaded'),
      (5, 'Loading Completed', 'Loading has been completed'),
      (6, 'Dispatch Started', 'Dispatch has been started'),
      (7, 'In Transit', 'You are on the way to delivery'),
      (8, 'Reached Delivery Location', 'You have reached the delivery point'),
      (9, 'Upload Delivery Proof', 'Upload photos / proof of delivery'),
      (10, 'Confirm Delivery', 'Confirm delivery after handover'),
      (11, 'Trip Completed', 'This trip will be marked as completed'),
    ];

    return definitions.map((d) {
      final (num, title, sub) = d;
      final state = num <= completedUpTo
          ? _StepState.completed
          : num == activeStep
              ? _StepState.active
              : _StepState.pending;
      return _Step(
        number: num,
        title: title,
        subtitle: sub,
        state: state,
        time: state != _StepState.pending ? timeFor(num) : null,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Column(
      children: steps.asMap().entries.map((e) {
        final isLast = e.key == steps.length - 1;
        return _StepRow(step: e.value, isLast: isLast);
      }).toList(),
    );
  }
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final bool isLast;

  const _StepRow({required this.step, required this.isLast});

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
          // Circle + connector line column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Number circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                  ),
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
                // Connector line
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
          // Text + timestamp
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      step.time ?? '--',
                      style: AppTypography.caption.copyWith(
                        color: step.state != _StepState.pending
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  // Expand chevron (decorative, for future use)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plants card (collapsible) ──────────────────────────────────────────────────

class _PlantsCard extends StatelessWidget {
  final List<DispatchItem> items;
  final bool expanded;
  final VoidCallback onToggle;

  const _PlantsCard({
    required this.items,
    required this.expanded,
    required this.onToggle,
  });

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
                          'Plants to Deliver (${items.length})',
                          style: AppTypography.h4,
                        ),
                        Text(
                          'Total Qty: $_totalQty',
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

// ── Sticky bottom action bar ───────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final String status;
  final bool busy;
  final String? destinationAddress;
  final VoidCallback onAccept;
  final VoidCallback onRefresh;
  final VoidCallback onNavigate;
  final VoidCallback onStartJourney;
  final VoidCallback onAddEvent;
  final VoidCallback onUploadProof;
  final VoidCallback onCompleteDelivery;

  const _BottomActionBar({
    required this.status,
    required this.busy,
    required this.destinationAddress,
    required this.onAccept,
    required this.onRefresh,
    required this.onNavigate,
    required this.onStartJourney,
    required this.onAddEvent,
    required this.onUploadProof,
    required this.onCompleteDelivery,
  });

  @override
  Widget build(BuildContext context) {
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
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 12),
          child: _buildButtons(context),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    switch (status) {
      case 'PENDING':
        return _PrimaryBtn(
          icon: Icons.check_circle_outline_rounded,
          label: 'Accept Trip',
          busy: busy,
          onPressed: onAccept,
        );

      case 'ACCEPTED':
        return SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape:
                  RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh Status'),
          ),
        );

      case 'DISPATCHED':
        return Row(
          children: [
            _OutlineIconBtn(
              icon: Icons.map_rounded,
              label: 'Maps',
              onPressed: destinationAddress != null ? onNavigate : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: _PrimaryBtn(
                icon: Icons.play_arrow_rounded,
                label: 'Start Journey',
                busy: busy,
                onPressed: onStartJourney,
              ),
            ),
          ],
        );

      case 'IN_TRANSIT':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _OutlineIconBtn(
                  icon: Icons.navigation_rounded,
                  label: 'Navigate',
                  onPressed: destinationAddress != null ? onNavigate : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OutlineIconBtn(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add Event',
                  onPressed: onAddEvent,
                  color: AppColors.blue600,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OutlineIconBtn(
                  icon: Icons.photo_camera_outlined,
                  label: 'Upload Proof',
                  onPressed: onUploadProof,
                  color: AppColors.amber600,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _PrimaryBtn(
              icon: Icons.where_to_vote_rounded,
              label: 'Complete Delivery',
              busy: busy,
              onPressed: onCompleteDelivery,
            ),
          ],
        );

      case 'DELIVERED':
        return SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain.withValues(alpha: 0.15),
              disabledBackgroundColor: AppColors.forest100,
              disabledForegroundColor: AppColors.primaryMain,
              shape:
                  RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            ),
            icon: const Icon(Icons.check_circle_rounded),
            label: Text('Trip Completed', style: AppTypography.label),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Button helpers ─────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryMain,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(label, style: AppTypography.label),
      ),
    );
  }
}

class _OutlineIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _OutlineIconBtn({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: AppSpacing.buttonHeight,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            padding: EdgeInsets.zero,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }
}
