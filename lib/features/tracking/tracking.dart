import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class TrackingPoint {
  final int id;
  final int? vehicleId;
  final int? driverId;
  final int? dispatchId;
  final double latitude;
  final double longitude;
  final String trackedAt;
  final String? notes;

  const TrackingPoint({
    required this.id,
    this.vehicleId,
    this.driverId,
    this.dispatchId,
    required this.latitude,
    required this.longitude,
    required this.trackedAt,
    this.notes,
  });

  factory TrackingPoint.fromJson(Map<String, dynamic> j) => TrackingPoint(
        id: (j['id'] as num).toInt(),
        vehicleId: (j['vehicle_id'] as num?)?.toInt(),
        driverId: (j['driver_id'] as num?)?.toInt(),
        dispatchId: (j['dispatch_id'] as num?)?.toInt(),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        trackedAt: j['tracked_at'] as String,
        notes: j['notes'] as String?,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class TrackingRepository {
  final ApiClient _client;
  TrackingRepository(this._client);

  Future<List<TrackingPoint>> getDispatchTracking(int dispatchId) async {
    return _client.get(
      ApiConstants.dispatchTracking(dispatchId),
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return (d['tracking'] as List<dynamic>)
            .map((e) => TrackingPoint.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<TrackingPoint?> getDispatchTrackingLatest(int dispatchId) async {
    try {
      return _client.get(
        ApiConstants.dispatchTrackingLatest(dispatchId),
        fromJson: (data) {
          final d = data as Map<String, dynamic>;
          final t = d['tracking'];
          if (t == null) return null;
          return TrackingPoint.fromJson(t as Map<String, dynamic>);
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<TrackingPoint> postLocation({
    required double latitude,
    required double longitude,
    int? vehicleId,
    int? driverId,
    int? dispatchId,
    String? notes,
  }) async {
    return _client.post(
      ApiConstants.postTracking,
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (driverId != null) 'driver_id': driverId,
        if (dispatchId != null) 'dispatch_id': dispatchId,
        if (notes != null) 'notes': notes,
      },
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        return TrackingPoint.fromJson(d['tracking'] as Map<String, dynamic>);
      },
    );
  }

  Future<void> postLiveLocation({
    required double latitude,
    required double longitude,
    required int dispatchId,
    int? driverUserId,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.trackingLive,
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'dispatch_id': dispatchId,
        if (driverUserId != null) 'driver_user_id': driverUserId,
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(ApiClient.instance),
);

final dispatchTrackingProvider =
    FutureProvider.family<List<TrackingPoint>, int>((ref, dispatchId) async {
  return ref.watch(trackingRepositoryProvider).getDispatchTracking(dispatchId);
});
