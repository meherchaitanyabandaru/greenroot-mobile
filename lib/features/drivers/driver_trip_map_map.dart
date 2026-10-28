part of 'driver_trip_map_screen.dart';

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
      // A third of the screen (max 292): on small phones a fixed 292 left the
      // journey and trip details a few pixels between the map and the buttons.
      height: (MediaQuery.sizeOf(context).height * 0.34).clamp(170.0, 292.0),
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
                ],
              ),
              // Truck — glides to each new position, pulses when IN_TRANSIT
              if (truckLatLng != null)
                GlidingTruckLayer(point: truckLatLng, active: isInTransit),
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
