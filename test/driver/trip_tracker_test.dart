import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:greenroot_mobile/features/drivers/trip_tracker.dart';
import 'package:greenroot_mobile/features/tracking/tracking.dart';

import '../helpers/fake_api_client.dart';

Position _fix(double lat, DateTime at) => Position(
      latitude: lat,
      longitude: 78.4,
      timestamp: at,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Map<String, dynamic> _point() => {
      'tracking': {
        'id': 1,
        'latitude': 17.4,
        'longitude': 78.4,
        'tracked_at': '2026-10-28T08:00:00Z',
      },
    };

void main() {
  late FakeApiClient fake;
  final tracker = TripTracker.instance;
  setUp(() async {
    fake = FakeApiClient()..reset();
    await tracker.stop();
    tracker.attach(22, TrackingRepository(fake.apiClient));
  });

  test('no signal: the point is held, then sent with its own time', () async {
    final t1 = DateTime.utc(2026, 10, 28, 8);
    fake.enqueue(type: FakeResponseType.networkError);
    await tracker.add(_fix(17.40, t1));
    expect(tracker.heldCount, 1);

    // The next fix: the held point goes first, then the new one, then live.
    tracker.debugSkipThrottle();
    fake
      ..enqueue(response: _point())
      ..enqueue(response: _point())
      ..enqueue(response: {'location': null});
    await tracker.add(_fix(17.41, t1.add(const Duration(seconds: 30))));

    expect(tracker.heldCount, 0);
    final posts =
        fake.calls.where((c) => c.path.endsWith('/tracking')).toList();
    expect(posts[posts.length - 2].data['recorded_at'],
        '2026-10-28T08:00:00.000Z',);
    expect(posts.last.data['recorded_at'], '2026-10-28T08:00:30.000Z');
    expect(fake.calls.last.path, endsWith('/tracking/live'));
  });

  test('fixes closer than 30 s are not sent twice', () async {
    fake.enqueue(response: _point());
    fake.enqueue(response: {'location': null});
    final t = DateTime.utc(2026, 10, 28, 8);
    await tracker.add(_fix(17.40, t));
    final sent = fake.calls.length;
    await tracker.add(_fix(17.41, t.add(const Duration(seconds: 5))));
    expect(fake.calls.length, sent);
  });

  test('trip no longer in transit (409): tracking stops', () async {
    fake.enqueue(type: FakeResponseType.conflict);
    await tracker.add(_fix(17.40, DateTime.utc(2026, 10, 28, 9)));
    expect(tracker.dispatchId, isNull);
    expect(tracker.heldCount, 0);

    // An open trip map ticks start() every 30 s: an ended trip must stay ended.
    await tracker.start(22, TrackingRepository(fake.apiClient));
    expect(tracker.dispatchId, isNull);
  });
}
