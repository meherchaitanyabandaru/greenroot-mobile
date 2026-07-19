// Unit tests for SessionNotifier — covers:
//   - bootstrap: no session → unauthenticated (works because SecureStorage
//     returns null/false when plugin unavailable in unit tests)
//   - bootstrap: user fetch 401 → unauthenticated (via fake HTTP)
//   - logout clears user/role/token state
//   - setActiveRole updates role without clearing user
//   - SessionState computed properties
//
// NOTE: flutter_secure_storage plugin is unavailable in dart unit tests
// (MissingPluginException is swallowed inside SecureStorageService).
// Tests that require real token persistence are covered by integration tests.
// Here we test the state machine behaviour of SessionNotifier.

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

import '../helpers/test_data.dart';

class _FakeAuthRepo extends AuthRepository {
  bool _sessionValid;
  final UserProfile? fakeUser;
  final List<Workspace> fakeWorkspaces;
  final List<AppRole> fakeRoles;
  final AppError? bootstrapError;

  _FakeAuthRepo({
    bool sessionValid = false,
    this.fakeUser,
    this.fakeWorkspaces = const [],
    this.fakeRoles = const [],
    this.bootstrapError,
  })  : _sessionValid = sessionValid,
        super(_makeDatasource());

  static AuthRemoteDataSource _makeDatasource() {
    try {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
      ApiClient.init();
    } catch (_) {}
    return AuthRemoteDataSource(ApiClient.instance);
  }

  @override
  Future<bool> hasValidSession() async => _sessionValid;

  @override
  Future<UserProfile> getCurrentUser() async {
    if (bootstrapError != null) throw bootstrapError!;
    return fakeUser ?? _defaultUser();
  }

  @override
  Future<List<Workspace>> getWorkspaces() async => fakeWorkspaces;

  @override
  Future<List<AppRole>> getUserRoles() async => fakeRoles;

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
    _sessionValid = false;
  }

  @override
  Future<void> saveActiveRole(AppRole role) async {}

  static UserProfile _defaultUser() => const UserProfile(
        id: kTestUserId,
        firstName: 'Ravi',
        lastName: 'Buyer',
        mobile: kTestMobile,
        mobileVerified: true,
      );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
      ApiClient.init();
    } catch (_) {}
  });

  group('SessionNotifier.bootstrap', () {
    test('no stored session → unauthenticated', () async {
      final notifier = SessionNotifier(_FakeAuthRepo(sessionValid: false));
      await notifier.bootstrap();

      expect(notifier.state.status, SessionStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    });

    test('valid session, user fetched → authenticated', () async {
      final notifier = SessionNotifier(
        _FakeAuthRepo(
          sessionValid: true,
          fakeUser: const UserProfile(
            id: kTestUserId,
            firstName: 'Ravi',
            lastName: 'Buyer',
            mobile: kTestMobile,
            mobileVerified: true,
          ),
          fakeWorkspaces: [
            Workspace.fromJson({'type': 'PERSONAL'})
          ],
          fakeRoles: [AppRole.buyer],
        ),
      );
      await notifier.bootstrap();

      expect(notifier.state.status, SessionStatus.authenticated);
      expect(notifier.state.user?.id, kTestUserId);
      expect(notifier.state.user?.firstName, 'Ravi');
      expect(notifier.state.roles, contains(AppRole.buyer));
    });

    test('bootstrap: getCurrentUser throws UnauthorizedError → unauthenticated',
        () async {
      final notifier = SessionNotifier(
        _FakeAuthRepo(
          sessionValid: true,
          bootstrapError: const UnauthorizedError(),
        ),
      );
      await notifier.bootstrap();

      expect(notifier.state.status, SessionStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    });

    test('bootstrap status transitions: unknown → loading → authenticated',
        () async {
      final states = <SessionStatus>[];
      final notifier = SessionNotifier(
        _FakeAuthRepo(
          sessionValid: true,
          fakeUser: const UserProfile(id: 1, firstName: 'Test'),
        ),
      );
      // Capture state changes
      states.add(notifier.state.status); // initial
      final future = notifier.bootstrap();
      states.add(notifier.state.status); // during (loading)
      await future;
      states.add(notifier.state.status); // after

      expect(states[0], SessionStatus.unknown);
      expect(states[1], SessionStatus.loading);
      expect(states[2], SessionStatus.authenticated);
    });
  });

  group('SessionNotifier.logout', () {
    test('logout sets status to unauthenticated and clears all fields',
        () async {
      final notifier = SessionNotifier(
        _FakeAuthRepo(
          sessionValid: true,
          fakeUser: const UserProfile(id: kTestUserId, firstName: 'Ravi'),
          fakeWorkspaces: [
            Workspace.fromJson({'type': 'PERSONAL'})
          ],
          fakeRoles: [AppRole.buyer],
        ),
      );
      await notifier.bootstrap();
      expect(notifier.state.status, SessionStatus.authenticated);

      await notifier.logout();

      expect(notifier.state.status, SessionStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      expect(notifier.state.roles, isEmpty);
      expect(notifier.state.nurseryId, isNull);
      expect(notifier.state.activeRole, isNull);
    });
  });

  group('SessionNotifier state helpers', () {
    test('setActiveRole(null) clears role without clearing user', () async {
      final notifier = SessionNotifier(
        _FakeAuthRepo(
          sessionValid: true,
          fakeUser: const UserProfile(id: kTestUserId, firstName: 'Ravi'),
        ),
      );
      await notifier.bootstrap();
      expect(notifier.state.user, isNotNull);

      notifier.setActiveRole(null);
      expect(notifier.state.activeRole, isNull);
      expect(notifier.state.user, isNotNull,
          reason: 'setActiveRole must NOT clear the user profile');
    });

    test('updateUser replaces user in state while preserving roles', () async {
      final notifier = SessionNotifier(
        _FakeAuthRepo(
          sessionValid: true,
          fakeUser: const UserProfile(id: kTestUserId, firstName: 'Ravi'),
          fakeRoles: [AppRole.buyer],
        ),
      );
      await notifier.bootstrap();

      notifier
          .updateUser(const UserProfile(id: kTestUserId, firstName: 'Updated'));

      expect(notifier.state.user?.firstName, 'Updated');
      expect(notifier.state.roles, contains(AppRole.buyer));
    });
  });

  group('SessionState computed properties', () {
    test('isAuthenticated true only for authenticated status', () {
      expect(
        const SessionState(status: SessionStatus.authenticated).isAuthenticated,
        isTrue,
      );
      expect(
        const SessionState(status: SessionStatus.unauthenticated)
            .isAuthenticated,
        isFalse,
      );
      expect(
        const SessionState(status: SessionStatus.loading).isAuthenticated,
        isFalse,
      );
    });

    test('isLoading true only for loading status', () {
      expect(
        const SessionState(status: SessionStatus.loading).isLoading,
        isTrue,
      );
      expect(
        const SessionState(status: SessionStatus.authenticated).isLoading,
        isFalse,
      );
    });

    test('mobileWorkspaces excludes PERSONAL workspace', () {
      const s = SessionState(
        status: SessionStatus.authenticated,
        workspaces: [
          Workspace(type: 'PERSONAL'),
          Workspace(type: 'OWNED_NURSERY', nurseryId: 5, nurseryName: 'Test'),
        ],
      );
      expect(s.mobileWorkspaces.length, 1);
      expect(s.mobileWorkspaces.first.type, 'OWNED_NURSERY');
    });

    test('hasMultipleWorkspaces false for single business workspace', () {
      const s = SessionState(
        status: SessionStatus.authenticated,
        workspaces: [
          Workspace(type: 'OWNED_NURSERY', nurseryId: 5, nurseryName: 'Test'),
        ],
      );
      expect(s.hasMultipleWorkspaces, isFalse);
    });
  });
}
