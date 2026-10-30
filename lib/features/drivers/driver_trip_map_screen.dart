import 'trip_start_consent.dart';
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
import 'trip_tracker.dart';
import '../dispatches/delivery_confirmation.dart';
import '../../core/feedback/app_haptics.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/utilities/step_time.dart';

part 'driver_trip_map_actions.dart';
part 'driver_trip_map_journey.dart';
part 'driver_trip_map_map.dart';

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
            child: AppLoader(),),
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
    final display = LifecyclePresenter.forDispatch(
      dispatch: dispatch,
      role: LifecycleRole.driver,
    );
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
                          ClipboardData(text: dispatch.dispatchCode),);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trip code copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded,
                        size: 13, color: AppColors.textMuted,),
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
      {super.key, required this.dispatch, required this.dispatchId,});

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
  // A fix that never comes would hold _postingGps and stop all posting.
  static const _gpsSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 20),
  );

  // Geocoded markers
  LatLng? _loadingPointLatLng;
  LatLng? _deliveryPointLatLng;
  String? _nurseryName;

  // Tracking history
  List<TrackingPoint> _trackingPts = [];

  // UI state — timeline starts collapsed so the map is the focus
  // Before dispatch there is no map: the journey is the screen, so show it.
  late bool _journeyExpanded = !_usesLiveMap(widget.dispatch.status);
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

    final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: _gpsSettings);
    } catch (_) {
      return; // GPS off or no fix; the 30 s posting retries.
    }
    if (!mounted) return;
    setState(() {
      _devicePos = pos;
      _locationGranted = true;
    });
    _fitBounds();
  }

  // Sending runs in TripTracker (keeps going off this screen); the timer here
  // only moves this screen's truck marker.
  void _startGpsPosting() {
    TripTracker.instance
        .start(widget.dispatchId, ref.read(trackingRepositoryProvider));
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(TripTracker.interval, (_) => _postGps());
  }

  Future<void> _postGps() async {
    if (_postingGps) return;
    _postingGps = true;
    try {
      final pos =
          await Geolocator.getCurrentPosition(locationSettings: _gpsSettings);
      if (mounted) setState(() => _devicePos = pos);
      // Started before the location prompt was answered? This restarts it (no-op if running).
      await TripTracker.instance
          .start(widget.dispatchId, ref.read(trackingRepositoryProvider));
      await TripTracker.instance.add(pos); // sent now unless one went out <24 s ago
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
        // Truck at the destination = zero-size bounds; past ~18 there are no tiles.
        maxZoom: 16,
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
            double.parse(r['lat'] as String), double.parse(r['lon'] as String),);
      }
    } catch (_) {}
    return null;
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  // Accepting means choosing the lorry: the trip preview does both.
  Future<void> _acceptTrip() async {
    final code = widget.dispatch.tripCode;
    if (code == null || code.isEmpty) return;
    await context.push('/driver/scan/preview?code=${Uri.encodeQueryComponent(code)}');
    ref.invalidate(dispatchDetailProvider(widget.dispatchId));
    ref.invalidate(activeDriverTripProvider);
  }

  Future<void> _startJourney() async {
    if (!{'ACCEPTED', 'DISPATCHED'}.contains(widget.dispatch.status)) {
      _snack('Cannot start — loading is not yet complete.', isError: true);
      return;
    }
    final consent = await startTripConsent(context, ref, widget.dispatch);
    if (consent == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .updateStatus(widget.dispatchId, 'IN_TRANSIT', consent: consentOrNull(consent));
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
    // The customer's code confirms delivery (see delivery_confirmation.dart).
    final done = await showDeliverSheet(context, ref, widget.dispatch);
    if (done == null || !mounted) return;
    _gpsTimer?.cancel();
    await TripTracker.instance.end(widget.dispatchId);
    ref.invalidate(dispatchDetailProvider(widget.dispatchId));
    ref.invalidate(orderDetailProvider(widget.dispatch.orderId));
    ref.invalidate(orderListProvider);
    ref.invalidate(buyingOrderListProvider);
    ref.invalidate(activeDriverTripProvider);
    _snack('Delivery completed. Well done!');
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
    isError ? AppHaptics.error() : AppHaptics.success();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.red600 : AppColors.primaryMain,
      duration: const Duration(seconds: 2),
    ),);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.dispatch;

    final isDelivered = d.status == 'DELIVERED' || d.status == 'CANCELLED';
    final showMap = _usesLiveMap(d.status);

    // On the road, what is left from the truck; before that, the whole trip.
    final pos = _devicePos;
    final from = d.status == 'IN_TRANSIT' && pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _loadingPointLatLng;
    double? distKm;
    if (showMap && from != null && _deliveryPointLatLng != null) {
      const calc = Distance();
      distKm = calc.as(LengthUnit.Kilometer, from, _deliveryPointLatLng!);
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
                    trip: d,
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
