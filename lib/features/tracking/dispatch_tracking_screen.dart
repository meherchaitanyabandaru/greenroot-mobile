import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'tracking.dart';

class DispatchTrackingScreen extends ConsumerStatefulWidget {
  final int dispatchId;
  final String? title;
  final bool isDriver;

  const DispatchTrackingScreen({
    super.key,
    required this.dispatchId,
    this.title,
    this.isDriver = false,
  });

  @override
  ConsumerState<DispatchTrackingScreen> createState() =>
      _DispatchTrackingScreenState();
}

class _DispatchTrackingScreenState
    extends ConsumerState<DispatchTrackingScreen> {
  final _mapController = MapController();
  List<TrackingPoint> _points = [];
  bool _loading = true;
  bool _postingLocation = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTracking();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadTracking(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadTracking({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final points = await ref
          .read(trackingRepositoryProvider)
          .getDispatchTracking(widget.dispatchId);
      if (mounted) {
        setState(() {
          _points = points;
          _loading = false;
          _error = null;
        });
        if (points.isNotEmpty) {
          final last = points.last;
          _mapController.move(
              LatLng(last.latitude, last.longitude), 14);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _shareLocation() async {
    setState(() => _postingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permission required to share location')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await ref.read(trackingRepositoryProvider).postLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            dispatchId: widget.dispatchId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location shared successfully'),
            backgroundColor: AppColors.primaryMid,
          ),
        );
        _loadTracking(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _postingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title ?? 'Track Shipment'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadTracking(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (_loading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(
                      color: AppColors.primaryMain),
                ),
              ),
            ),
          if (!_loading && _error != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.textMuted, size: 40),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Could not load tracking data',
                          style: AppTypography.label),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: _loadTracking,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_loading && _error == null && _points.isEmpty)
            Center(
              child: Card(
                margin: const EdgeInsets.all(AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off_outlined,
                          color: AppColors.textMuted, size: 48),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No tracking data yet',
                          style: AppTypography.label),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Waiting for the driver to share location.',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final latLngs = _points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Default to center of India if no points
    final center = latLngs.isNotEmpty ? latLngs.last : const LatLng(20.5937, 78.9629);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: latLngs.isNotEmpty ? 14 : 5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.greenroot.greenroot_mobile',
        ),
        if (latLngs.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLngs,
                strokeWidth: 4,
                color: AppColors.blue600,
              ),
            ],
          ),
        if (latLngs.isNotEmpty)
          MarkerLayer(
            markers: [
              if (latLngs.length > 1)
                Marker(
                  point: latLngs.first,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryMid,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              Marker(
                point: latLngs.last,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: AppColors.red600,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_points.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryMid,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Last updated: ${_formatTime(_points.last.trackedAt)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  '${_points.length} point${_points.length == 1 ? '' : 's'}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        if (widget.isDriver)
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _postingLocation ? null : _shareLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              icon: _postingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                _postingLocation ? 'Sharing...' : 'Share My Location',
                style: AppTypography.label,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
