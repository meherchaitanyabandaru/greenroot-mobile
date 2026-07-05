import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/geocoding/geocoding_provider.dart';
import '../../core/services/geocoding/geocoding_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

// ── Map picker screen ─────────────────────────────────────────────────────────
//
// Uber/Swiggy-style center-pin picker:
//  • Map fills the screen — user drags the map, pin stays fixed at center
//  • On drag-end: reverse geocode fires (800 ms debounce, CancelToken)
//  • Bottom panel: city / state (always) + pincode (when OSM has it)
//  • "Use my location" button via geolocator
//  • Search bar: forward geocode → move map to suggestion
//  • Confirm: pop with MapPickResult

class AddressMapPickerScreen extends ConsumerStatefulWidget {
  final MapPickResult? initial; // pre-center on edit / re-pick

  const AddressMapPickerScreen({super.key, this.initial});

  @override
  ConsumerState<AddressMapPickerScreen> createState() =>
      _AddressMapPickerScreenState();
}

class _AddressMapPickerScreenState
    extends ConsumerState<AddressMapPickerScreen> {
  static const _indiaCenter = LatLng(20.5937, 78.9629);
  static const _defaultZoom = 5.0;
  static const _pickZoom = 15.0;

  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // Geocoding state
  CancelToken? _reverseCancelToken;
  CancelToken? _searchCancelToken;
  Timer? _reverseDebounce;
  Timer? _searchDebounce;

  bool _reversing = false;
  bool _searching = false;
  bool _mapMoving = false;
  bool _locatingDevice = false; // true while geolocator is running
  // true until the first real location is pinned (auto or manual).
  // Prevents the India-center default from triggering a bogus reverse geocode.
  bool _awaitingInitialLocation = true;
  AddressSuggestion? _geocoded; // result of last reverse geocode
  String? _reverseError;
  List<AddressSuggestion> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initial != null) {
        final i = widget.initial!;
        _awaitingInitialLocation = false;
        _mapController.move(LatLng(i.latitude, i.longitude), _pickZoom);
        setState(() {
          _geocoded = AddressSuggestion(
            displayName: '${i.city}, ${i.state}',
            city: i.city,
            state: i.state,
            postalCode: i.postalCode,
            country: i.country,
            latitude: i.latitude,
            longitude: i.longitude,
          );
        });
      } else {
        _tryMyLocation();
      }
    });
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _searchDebounce?.cancel();
    _reverseCancelToken?.cancel('disposed');
    _searchCancelToken?.cancel('disposed');
    _mapController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── My location ─────────────────────────────────────────────────────────────

  Future<void> _tryMyLocation() async {
    if (!mounted) return;
    setState(() { _locatingDevice = true; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        // Permission denied — unblock the map so the user can pan manually
        setState(() {
          _locatingDevice = false;
          _awaitingInitialLocation = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _locatingDevice = false;
        _awaitingInitialLocation = false;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), _pickZoom);
      _scheduleReverseGeocode();
    } catch (_) {
      if (!mounted) return;
      // Location unavailable — unblock so user can drag manually
      setState(() {
        _locatingDevice = false;
        _awaitingInitialLocation = false;
      });
    }
  }

  // ── Map events ──────────────────────────────────────────────────────────────

  void _onMapEvent(MapEvent event) {
    // Ignore all events until we have a real first location.
    // This prevents the India-center default from triggering a reverse geocode.
    if (_awaitingInitialLocation) return;

    if (event is MapEventMoveStart || event is MapEventRotateStart) {
      _reverseDebounce?.cancel();
      _reverseCancelToken?.cancel('map moved');
      setState(() {
        _mapMoving = true;
        _geocoded = null;
        _reverseError = null;
      });
    }
    if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
      setState(() => _mapMoving = false);
      _scheduleReverseGeocode();
    }
  }

  void _zoomIn() {
    final cam = _mapController.camera;
    _mapController.move(cam.center, (cam.zoom + 1).clamp(4, 19));
  }

  void _zoomOut() {
    final cam = _mapController.camera;
    _mapController.move(cam.center, (cam.zoom - 1).clamp(4, 19));
  }

  void _scheduleReverseGeocode() {
    _reverseDebounce?.cancel();
    setState(() { _reversing = true; _reverseError = null; });
    _reverseDebounce =
        Timer(const Duration(milliseconds: 800), _doReverseGeocode);
  }

  Future<void> _doReverseGeocode() async {
    _reverseCancelToken?.cancel('new reverse');
    _reverseCancelToken = CancelToken();
    final center = _mapController.camera.center;
    try {
      final svc = ref.read(geocodingServiceProvider);
      final result = await svc.reverseGeocode(
        center.latitude,
        center.longitude,
        cancelToken: _reverseCancelToken,
      );
      if (!mounted) return;
      setState(() {
        _geocoded = result;
        _reversing = false;
        _reverseError = result == null
            ? 'Could not identify location. Try zooming in.'
            : null;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || !mounted) return;
      setState(() {
        _reversing = false;
        _reverseError = 'Network error. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reversing = false;
        _reverseError = 'Could not identify location. Try again.';
      });
    }
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel('new search');
    final q = v.trim();
    if (q.length < 3) {
      setState(() {
        _searchResults = [];
        _searching = false;
        _showSearchResults = false;
      });
      return;
    }
    setState(() { _searching = true; _showSearchResults = true; });
    _searchDebounce =
        Timer(const Duration(milliseconds: 400), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    _searchCancelToken = CancelToken();
    try {
      final svc = ref.read(geocodingServiceProvider);
      final results =
          await svc.search(q, cancelToken: _searchCancelToken);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || !mounted) return;
      setState(() { _searching = false; _searchResults = []; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _searching = false; _searchResults = []; });
    }
  }

  void _onSearchSelected(AddressSuggestion s) {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
      _searching = false;
    });
    if (s.latitude != null && s.longitude != null) {
      _mapController.move(
          LatLng(s.latitude!, s.longitude!), _pickZoom);
      _scheduleReverseGeocode();
    }
  }

  // ── Confirm ─────────────────────────────────────────────────────────────────

  void _confirm() {
    final g = _geocoded;
    if (g == null) return;
    final city = g.city ?? '';
    final state = g.state ?? '';
    if (city.isEmpty || state.isEmpty) return;

    final center = _mapController.camera.center;
    Navigator.pop(
      context,
      MapPickResult(
        latitude: center.latitude,
        longitude: center.longitude,
        city: city,
        state: state,
        postalCode: g.postalCode,
        country: g.country ?? 'India',
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canConfirm = _geocoded?.city?.isNotEmpty == true &&
        _geocoded?.state?.isNotEmpty == true &&
        !_mapMoving &&
        !_reversing &&
        !_awaitingInitialLocation;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _indiaCenter,
              initialZoom: _defaultZoom,
              minZoom: 4,
              maxZoom: 19,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.greenroot.app',
                maxZoom: 19,
              ),
            ],
          ),

          // ── Center pin (tip at exact center) ──────────────────────────────
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                // Pin total height ≈ 52 px (circle 40 + tail 12);
                // shift up by half so the tip lands at screen center
                offset: const Offset(0, -26),
                child: _CenterPin(
                  moving: _mapMoving,
                  loading: _reversing && !_mapMoving,
                ),
              ),
            ),
          ),

          // ── AppBar row ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back + search bar row
                  Row(
                    children: [
                      _MapIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _SearchBar(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        searching: _searching,
                        onChanged: _onSearchChanged,
                        onClear: () {
                          _searchCtrl.clear();
                          _searchFocus.unfocus();
                          setState(() {
                            _searchResults = [];
                            _showSearchResults = false;
                            _searching = false;
                          });
                        },
                      )),
                    ],
                  ),

                  // Search results dropdown
                  if (_showSearchResults)
                    _SearchDropdown(
                      results: _searchResults,
                      loading: _searching,
                      onTap: _onSearchSelected,
                    ),
                ],
              ),
            ),
          ),

          // ── Right-side controls: zoom + my-location ────────────────────────
          Positioned(
            right: 16,
            bottom: 236,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(
                  icon: Icons.add_rounded,
                  onTap: _zoomIn,
                  tooltip: 'Zoom in',
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.remove_rounded,
                  onTap: _zoomOut,
                  tooltip: 'Zoom out',
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: _locatingDevice
                      ? Icons.sync_rounded
                      : Icons.my_location_rounded,
                  onTap: _locatingDevice ? () {} : _tryMyLocation,
                  tooltip: 'Use my location',
                ),
              ],
            ),
          ),

          // ── Bottom panel ───────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              awaitingLocation: _awaitingInitialLocation,
              locatingDevice: _locatingDevice,
              moving: _mapMoving,
              loading: _reversing,
              geocoded: _geocoded,
              error: _reverseError,
              canConfirm: canConfirm,
              onConfirm: _confirm,
              onRetry: _scheduleReverseGeocode,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Center pin widget ─────────────────────────────────────────────────────────

class _CenterPin extends StatelessWidget {
  final bool moving;
  final bool loading;

  const _CenterPin({required this.moving, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: moving ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryMain.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 22),
          ),
        ),
        // Pin tail
        Container(
          width: 2,
          height: 12,
          color: AppColors.primaryMain,
        ),
        // Shadow dot (visual ground contact)
        AnimatedOpacity(
          opacity: moving ? 0.3 : 0.7,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 10,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Floating search bar ───────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search city, area, or landmark...',
          hintStyle:
              AppTypography.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.primaryMain, size: 20),
          suffixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryMain),
                  ),
                )
              : controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textMuted),
                      onPressed: onClear,
                    )
                  : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ── Search results dropdown ───────────────────────────────────────────────────

class _SearchDropdown extends StatelessWidget {
  final List<AddressSuggestion> results;
  final bool loading;
  final ValueChanged<AddressSuggestion> onTap;

  const _SearchDropdown(
      {required this.results, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading && results.isEmpty) {
      return const SizedBox.shrink();
    }
    if (results.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6, left: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < results.length; i++) ...[
            InkWell(
              onTap: () => onTap(results[i]),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primaryMain, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _summary(results[i]),
                        style: AppTypography.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < results.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  static String _summary(AddressSuggestion s) {
    final parts = [
      if (s.addressLine1?.isNotEmpty == true) s.addressLine1!,
      if (s.addressLine2?.isNotEmpty == true) s.addressLine2!,
      if (s.city?.isNotEmpty == true) s.city!,
      if (s.state?.isNotEmpty == true) s.state!,
      if (s.postalCode?.isNotEmpty == true) s.postalCode!,
    ];
    return parts.take(4).join(', ').isNotEmpty
        ? parts.take(4).join(', ')
        : s.displayName;
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final bool awaitingLocation; // geolocator hasn't responded yet
  final bool locatingDevice;   // actively fetching GPS
  final bool moving;
  final bool loading;
  final AddressSuggestion? geocoded;
  final String? error;
  final bool canConfirm;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  const _BottomPanel({
    required this.awaitingLocation,
    required this.locatingDevice,
    required this.moving,
    required this.loading,
    required this.geocoded,
    required this.error,
    required this.canConfirm,
    required this.onConfirm,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Instruction
          Text(
            awaitingLocation
                ? 'Detecting your location…'
                : moving
                    ? 'Move the map to your location'
                    : 'Pin your delivery location',
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Location info
          if (awaitingLocation || locatingDevice)
            const _LocationDetectingRow()
          else if (moving || (loading && geocoded == null))
            const _LocationLoadingRow()
          else if (error != null)
            _LocationErrorRow(error: error!, onRetry: onRetry)
          else if (geocoded != null)
            _LocationResultRow(geocoded: geocoded!)
          else
            const _LocationEmptyRow(),

          const SizedBox(height: AppSpacing.lg),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: canConfirm ? onConfirm : null,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Confirm Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationDetectingRow extends StatelessWidget {
  const _LocationDetectingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryMain),
          ),
          const SizedBox(width: 12),
          Text('Detecting your location…',
              style: AppTypography.body
                  .copyWith(color: AppColors.primaryMain)),
        ],
      ),
    );
  }
}

class _LocationLoadingRow extends StatelessWidget {
  const _LocationLoadingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryMain),
          ),
          const SizedBox(width: 12),
          Text('Identifying location...',
              style: AppTypography.body
                  .copyWith(color: AppColors.primaryMain)),
        ],
      ),
    );
  }
}

class _LocationResultRow extends StatelessWidget {
  final AddressSuggestion geocoded;
  const _LocationResultRow({required this.geocoded});

  @override
  Widget build(BuildContext context) {
    final city = geocoded.city ?? '';
    final state = geocoded.state ?? '';
    final pin = geocoded.postalCode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primaryMain.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_rounded,
              color: AppColors.primaryMain, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.isNotEmpty && state.isNotEmpty
                      ? '$city, $state'
                      : city.isNotEmpty
                          ? city
                          : state,
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                if (pin?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text('PIN: $pin',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ] else ...[
                  const SizedBox(height: 2),
                  Text('Pincode not available — you\'ll enter it next',
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.amber700)),
                ],
              ],
            ),
          ),
          // Lock icon: these fields will be locked in the form
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: AppColors.primaryMain),
        ],
      ),
    );
  }
}

class _LocationErrorRow extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _LocationErrorRow({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amber100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.amber700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.amber700)),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Retry',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _LocationEmptyRow extends StatelessWidget {
  const _LocationEmptyRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded,
              color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Text('Drag the map to pin your location',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Map icon button ───────────────────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _MapIconButton(
      {required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
