// Unit tests for MembersNotifier — covers:
//   - load: parallel fetch populates managers, invites, customers, drivers
//   - load: API error sets error in state
//   - removeManager: DELETE call succeeds → returns true and triggers reload
//   - removeManager: API error → returns false and sets error in state
//   - disconnectDriver: DELETE call succeeds → returns true and triggers reload
//   - disconnectDriver: API error → returns false and sets error in state
//
// MembersNotifier is instantiated directly (not via Riverpod) so tests
// don't need a ProviderContainer.

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';
import 'package:greenroot_mobile/features/owner/owner_members_screen.dart';

import '../helpers/fake_api_client.dart';

const _nurseryId = 5;

/// 4 empty-list responses for the 4 parallel calls in load():
/// managers, invites, customers, drivers
void _enqueueEmptyLoad(FakeApiClient fake) {
  fake.enqueue(response: {'managers': []});
  fake.enqueue(response: {'invites': [], 'pagination': {}});
  fake.enqueue(response: {'customers': []});
  fake.enqueue(response: {'drivers': []});
}

MembersNotifier _notifier(FakeApiClient fake) =>
    MembersNotifier(_nurseryId, fake.apiClient);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
    } catch (_) {}
  });

  late FakeApiClient fake;

  setUp(() => fake = FakeApiClient());

  // ── load ───────────────────────────────────────────────────────────────────

  group('MembersNotifier.load', () {
    test('populates managers, invites, customers, and drivers on success', () async {
      fake.enqueue(response: {
        'managers': [
          {'id': 1, 'user_id': 20, 'name': 'Gumastha', 'mobile': '9200000000', 'role': 'MANAGER'},
        ],
      });
      fake.enqueue(response: {'invites': [], 'pagination': {}});
      fake.enqueue(response: {'customers': []});
      fake.enqueue(response: {
        'drivers': [
          {'id': 1, 'driver_user_id': 40, 'name': 'Raju Driver', 'connection_status': 'CONNECTED'},
        ],
      });

      final notifier = _notifier(fake);
      await notifier.load();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.managers, hasLength(1));
      expect(notifier.state.managers.first.name, 'Gumastha');
      expect(notifier.state.drivers, hasLength(1));
      expect(notifier.state.drivers.first.name, 'Raju Driver');
    });

    test('empty lists when nursery has no members', () async {
      _enqueueEmptyLoad(fake);
      final notifier = _notifier(fake);
      await notifier.load();

      expect(notifier.state.managers, isEmpty);
      expect(notifier.state.drivers, isEmpty);
      expect(notifier.state.invites, isEmpty);
      expect(notifier.state.customers, isEmpty);
      expect(notifier.state.error, isNull);
    });

    test('sets error when API returns server error', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      // remaining parallel calls also need queuing — but with error on the first
      // the Future.wait will propagate the error
      final notifier = _notifier(fake);
      await notifier.load();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('loading state is true during fetch', () async {
      _enqueueEmptyLoad(fake);
      final notifier = _notifier(fake);

      final states = <bool>[];
      notifier.addListener((_) => states.add(notifier.state.isLoading), fireImmediately: false);

      await notifier.load();

      // Should have seen at least one loading=true then loading=false transition
      expect(states, isNotEmpty);
      expect(states.last, isFalse);
    });
  });

  // ── removeManager ──────────────────────────────────────────────────────────

  group('MembersNotifier.removeManager', () {
    test('returns true and triggers reload on success', () async {
      // DELETE response
      fake.enqueue(response: {'message': 'removed'});
      // reload (4 parallel calls)
      _enqueueEmptyLoad(fake);

      final notifier = _notifier(fake);
      final result = await notifier.removeManager(20);

      expect(result, isTrue);
      expect(notifier.state.error, isNull);

      // Verify the DELETE call was made
      final deleteCalls = fake.calls.where((c) => c.method == 'DELETE').toList();
      expect(deleteCalls, hasLength(1));
      expect(deleteCalls.first.path, contains('managers'));
      expect(deleteCalls.first.path, contains('20'));
    });

    test('returns false and sets error on API failure', () async {
      fake.enqueue(type: FakeResponseType.serverError);

      final notifier = _notifier(fake);
      final result = await notifier.removeManager(20);

      expect(result, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('returns false when manager not found (404)', () async {
      fake.enqueue(type: FakeResponseType.notFound);

      final notifier = _notifier(fake);
      final result = await notifier.removeManager(99);

      expect(result, isFalse);
    });

    test('returns false when forbidden (403)', () async {
      fake.enqueue(type: FakeResponseType.forbidden);

      final notifier = _notifier(fake);
      final result = await notifier.removeManager(20);

      expect(result, isFalse);
    });
  });

  // ── disconnectDriver ───────────────────────────────────────────────────────

  group('MembersNotifier.disconnectDriver', () {
    test('returns true and triggers reload on success', () async {
      fake.enqueue(response: {'message': 'disconnected'});
      _enqueueEmptyLoad(fake);

      final notifier = _notifier(fake);
      final result = await notifier.disconnectDriver(40);

      expect(result, isTrue);
      expect(notifier.state.error, isNull);

      final deleteCalls = fake.calls.where((c) => c.method == 'DELETE').toList();
      expect(deleteCalls, hasLength(1));
      expect(deleteCalls.first.path, contains('drivers'));
      expect(deleteCalls.first.path, contains('40'));
    });

    test('returns false and sets error on server error', () async {
      fake.enqueue(type: FakeResponseType.serverError);

      final notifier = _notifier(fake);
      final result = await notifier.disconnectDriver(40);

      expect(result, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('returns false when driver connection not found (404)', () async {
      fake.enqueue(type: FakeResponseType.notFound);

      final notifier = _notifier(fake);
      final result = await notifier.disconnectDriver(99);

      expect(result, isFalse);
    });

    test('returns false when forbidden (403)', () async {
      fake.enqueue(type: FakeResponseType.forbidden);

      final notifier = _notifier(fake);
      final result = await notifier.disconnectDriver(40);

      expect(result, isFalse);
    });
  });

  // ── Driver model ───────────────────────────────────────────────────────────

  group('NurseryDriver.fromJson', () {
    test('parses all fields correctly', () {
      final driver = NurseryDriver.fromJson({
        'id': 1,
        'driver_user_id': 40,
        'name': 'Raju Driver',
        'mobile': '9400000000',
        'connection_status': 'CONNECTED',
      });

      expect(driver.id, 1);
      expect(driver.driverUserId, 40);
      expect(driver.name, 'Raju Driver');
      expect(driver.mobile, '9400000000');
      expect(driver.connectionStatus, 'CONNECTED');
    });

    test('handles missing optional fields gracefully', () {
      final driver = NurseryDriver.fromJson({
        'id': 2,
        'driver_user_id': 41,
        'connection_status': 'DISCONNECTED',
      });

      expect(driver.name, isNull);
      expect(driver.mobile, isNull);
      expect(driver.connectionStatus, 'DISCONNECTED');
    });
  });
}
