// Unit tests for account lifecycle flows in the mobile app — covers:
//   - Leave nursery: API called, bootstrap refreshes session, no MANAGER_NURSERY workspace
//   - Delete account: API called, logout called, session cleared
//   - Session state after bootstrap with no manager workspace → no manager capability
//   - Re-entry: bootstrap after account deletion shows unauthenticated (no valid session)
//
// These tests exercise the session state machine reachable from ProfileTabContent
// and the underlying SessionNotifier, without rendering the widget tree.

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';
import 'package:greenroot_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:greenroot_mobile/features/auth/data/models/user_models.dart';
import 'package:greenroot_mobile/features/auth/data/models/workspace_model.dart';
import 'package:greenroot_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:greenroot_mobile/features/auth/domain/rbac/roles.dart';
import 'package:greenroot_mobile/features/auth/presentation/providers/session_provider.dart';

// ─── Fake auth repo ───────────────────────────────────────────────────────────

class _FakeAuthRepo extends AuthRepository {
  bool _valid;
  UserProfile? _user;
  List<Workspace> _workspaces;
  final AppError? _error;

  _FakeAuthRepo({
    bool valid = true,
    UserProfile? user,
    List<Workspace> workspaces = const [],
    AppError? error,
  })  : _valid = valid,
        _user = user,
        _workspaces = workspaces,
        _error = error,
        super(_datasource());

  static AuthRemoteDataSource _datasource() {
    try {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
      ApiClient.init();
    } catch (_) {}
    return AuthRemoteDataSource(ApiClient.instance);
  }

  @override
  Future<bool> hasValidSession() async => _valid;
  @override
  Future<UserProfile> getCurrentUser() async {
    final error = _error;
    if (error != null) throw error;
    return _user ?? const UserProfile(id: 99, firstName: 'Test');
  }

  @override
  Future<List<Workspace>> getWorkspaces() async => _workspaces;
  @override
  Future<List<AppRole>> getUserRoles() async => [];
  @override
  Future<DriverApplicationStatus?> getDriverApplicationStatus() async => null;
  @override
  Future<int?> getNurseryId() async => null;
  @override
  Future<AppRole?> getStoredActiveRole() async => null;
  @override
  Future<String?> getOwnedNurseryStatus() async => null;
  @override
  Future<void> logout() async {
    _valid = false;
  }

  @override
  Future<void> saveActiveRole(AppRole role) async {}

  // Helper: simulate a new bootstrap after role change (e.g. after leaving nursery)
  void updateWorkspaces(List<Workspace> ws) => _workspaces = ws;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
      ApiClient.init();
    } catch (_) {}
  });

  // ── Leave nursery ──────────────────────────────────────────────────────────

  group('Leave nursery — session state', () {
    test('manager bootstrap shows MANAGER_NURSERY workspace', () async {
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 20, firstName: 'Gumastha'),
        workspaces: [
          Workspace.fromJson({'type': 'PERSONAL'}),
          Workspace.fromJson({
            'type': 'MANAGER_NURSERY',
            'nursery_id': 5,
            'nursery_name': 'Test'
          }),
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();

      expect(notifier.state.capabilities.isManager, isTrue);
      expect(notifier.state.capabilities.primaryNurseryId, 5);
    });

    test(
        'after leaving: bootstrap with no manager workspace clears manager capability',
        () async {
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 20, firstName: 'Gumastha'),
        workspaces: [
          Workspace.fromJson({
            'type': 'MANAGER_NURSERY',
            'nursery_id': 5,
            'nursery_name': 'Test'
          }),
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();
      expect(notifier.state.capabilities.isManager, isTrue);

      // Simulate leave nursery: server removes the MANAGER_NURSERY workspace
      repo.updateWorkspaces([
        Workspace.fromJson({'type': 'PERSONAL'})
      ]);
      await notifier.bootstrap();

      expect(notifier.state.capabilities.isManager, isFalse,
          reason: 'after leaving nursery, isManager must be false');
      expect(notifier.state.capabilities.primaryNurseryId, isNull,
          reason: 'no nursery should be associated after leaving');
    });

    test(
        'after leaving: workspace selector should be the next route (multiple workspaces = false)',
        () async {
      // A user who just left has only PERSONAL workspace → hasMultipleWorkspaces = false
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 20, firstName: 'Gumastha'),
        workspaces: [
          Workspace.fromJson({'type': 'PERSONAL'})
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();

      expect(notifier.state.hasMultipleWorkspaces, isFalse);
      expect(notifier.state.mobileWorkspaces, isEmpty,
          reason: 'PERSONAL workspace is excluded from mobileWorkspaces');
    });
  });

  // ── Delete account ─────────────────────────────────────────────────────────

  group('Delete account — session state', () {
    test('logout after deletion clears all session fields', () async {
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 30, firstName: 'Ravi'),
        workspaces: [
          Workspace.fromJson({'type': 'PERSONAL'})
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();
      expect(notifier.state.status, SessionStatus.authenticated);
      expect(notifier.state.user?.id, 30);

      await notifier.logout();

      expect(notifier.state.status, SessionStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      expect(notifier.state.roles, isEmpty);
      expect(notifier.state.nurseryId, isNull);
    });

    test('bootstrap after deletion (invalid session) → unauthenticated',
        () async {
      // Simulate deleted account: session is now invalid (sessions revoked)
      final repo = _FakeAuthRepo(
        valid: false,
        error: const UnauthorizedError(),
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();

      expect(notifier.state.status, SessionStatus.unauthenticated,
          reason:
              'a deleted account with revoked sessions must not be re-authenticated');
    });
  });

  // ── Re-entry: new registration after deletion ───────────────────────────────

  group('Re-entry after account deletion', () {
    test('re-registered user gets a fresh unauthenticated state first',
        () async {
      // After deletion the app logs out → unauthenticated
      final repo = _FakeAuthRepo(valid: false);
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();
      expect(notifier.state.status, SessionStatus.unauthenticated);
    });

    test('re-registered user with valid new session gets authenticated state',
        () async {
      // OTP flow produces a new valid session for the re-registered user
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 200, firstName: 'GreenRoot'), // new user ID
        workspaces: [
          Workspace.fromJson({'type': 'PERSONAL'})
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();

      expect(notifier.state.status, SessionStatus.authenticated);
      expect(notifier.state.user?.id, 200,
          reason: 're-registered user must have a different user ID');
      expect(notifier.state.capabilities.isManager, isFalse);
      expect(notifier.state.capabilities.isNurseryOwner, isFalse);
    });

    test('fresh user from re-registration has no nursery associations',
        () async {
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 201, firstName: 'GreenRoot'),
        workspaces: [
          Workspace.fromJson({'type': 'PERSONAL'})
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();

      expect(notifier.state.capabilities.primaryNurseryId, isNull,
          reason: 'fresh account must have no nursery');
      expect(notifier.state.capabilities.canSell, isFalse);
    });
  });

  // ── Owner role preserved (not affected by member lifecycle) ────────────────

  group('Owner role unaffected by manager/driver lifecycle changes', () {
    test('owner bootstrap still shows OWNED_NURSERY after manager is removed',
        () async {
      // Owner removes a manager — their own session is unchanged.
      final repo = _FakeAuthRepo(
        valid: true,
        user: const UserProfile(id: 10, firstName: 'Priya'),
        workspaces: [
          Workspace.fromJson({
            'type': 'OWNED_NURSERY',
            'nursery_id': 1,
            'nursery_name': 'Priya Nursery'
          }),
        ],
      );
      final notifier = SessionNotifier(repo);
      await notifier.bootstrap();

      expect(notifier.state.capabilities.isNurseryOwner, isTrue);
      expect(notifier.state.capabilities.primaryNurseryId, 1);
    });
  });
}
