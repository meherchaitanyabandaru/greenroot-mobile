import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors/app_error.dart';
import '../tracking/tracking.dart';

/// Sends the driver's position about every 30 s while a trip is in transit.
/// On Android it runs as a foreground service ("Sharing your location"), so it
/// keeps going when the driver leaves the map or locks the phone. Points that
/// cannot be sent (no signal) are held and sent later with their own time.
class TripTracker {
  TripTracker._();
  static final instance = TripTracker._();

  static const interval = Duration(seconds: 30);
  // shortcut: ~4 h of points at 30 s; older ones are dropped. Persist to disk if trips get longer offline.
  static const maxHeld = 500;

  int? _dispatchId;
  TrackingRepository? _repo;
  StreamSubscription<Position>? _sub;
  final _held = <Position>[];
  // Trips that are over (refused with 409/403, or delivered): never restarted.
  final _ended = <int>{};
  DateTime? _lastTaken;
  bool _sending = false;

  int? get dispatchId => _dispatchId;
  @visibleForTesting
  int get heldCount => _held.length;

  /// Starts (or keeps) tracking [dispatchId]. Safe to call on every screen open.
  Future<void> start(int dispatchId, TrackingRepository repo) async {
    if (_ended.contains(dispatchId)) return;
    if (_dispatchId == dispatchId && _sub != null) return;
    await stop();
    _dispatchId = dispatchId;
    _repo = repo;
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            intervalDuration: interval,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Delivery in progress',
              notificationText:
                  'Sharing your location with the customer until delivery.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high);
    // No permission / GPS off: forget the stream so the next start() retries.
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      add,
      onError: (_) {
        _sub?.cancel();
        _sub = null;
      },
    );
  }

  /// Tests: track [dispatchId] without the platform GPS stream.
  @visibleForTesting
  void attach(int dispatchId, TrackingRepository repo) {
    _dispatchId = dispatchId;
    _repo = repo;
  }

  /// Tests: the next fix is taken even if one came in under [interval].
  @visibleForTesting
  void debugSkipThrottle() => _lastTaken = null;

  /// The trip is delivered or cancelled: stop and never restart it.
  Future<void> end(int dispatchId) async {
    _ended.add(dispatchId);
    if (_dispatchId == dispatchId) await stop();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _dispatchId = null;
    _held.clear();
    _lastTaken = null;
  }

  /// A new fix: kept at most every [interval], then everything held is sent.
  Future<void> add(Position p) async {
    final now = DateTime.now();
    if (_lastTaken != null && now.difference(_lastTaken!) < interval * 0.8) {
      return;
    }
    _lastTaken = now;
    _held.add(p);
    if (_held.length > maxHeld) _held.removeAt(0);
    await _flush();
  }

  Future<void> _flush() async {
    final repo = _repo, id = _dispatchId;
    if (_sending || repo == null || id == null) return;
    _sending = true;
    try {
      while (_held.isNotEmpty) {
        final p = _held.first;
        await repo.postLocation(
          latitude: p.latitude,
          longitude: p.longitude,
          dispatchId: id,
          recordedAt: p.timestamp,
        );
        _held.removeAt(0);
        if (_held.isEmpty) {
          // Only the newest point moves the live marker.
          await repo
              .postLiveLocation(
                latitude: p.latitude,
                longitude: p.longitude,
                dispatchId: id,
              )
              .catchError((_) {});
        }
      }
    } on NetworkError {
      // no signal: keep the points for the next fix
    } on TimeoutError {
      // same
    } on ServerError {
      // same
    } on AppError {
      // 409 not in transit any more / 403: the trip is over for this phone
      _ended.add(id);
      await stop();
    } catch (_) {
      // unexpected: keep the points, the next fix retries
    } finally {
      _sending = false;
    }
  }
}
