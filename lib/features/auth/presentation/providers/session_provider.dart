import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/capabilities_model.dart';
import '../../data/models/user_models.dart';
import '../../data/models/workspace_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/rbac/permission_service.dart';
import '../../domain/rbac/roles.dart';
import 'auth_provider.dart';

// Carries suspension details through to the suspended screen.
class SuspensionInfo {
  final String? reason;
  final DateTime? suspendedAt;

  /// True when the owner's nursery (not the account itself) is suspended.
  final bool nursery;
  const SuspensionInfo({this.reason, this.suspendedAt, this.nursery = false});
}

enum SessionStatus {
  unknown,
  loading,
  authenticated,
  unauthenticated,
  suspended
}

class SessionState {
  final SessionStatus status;
  final UserProfile? user;
  final List<AppRole> roles;
  final List<Workspace> workspaces;
  final DriverApplicationStatus? driverApplication;
  final int? nurseryId;
  final String? ownedNurseryStatus;
  final AppRole? activeRole;
  final AppError? error;
  final SuspensionInfo? suspensionInfo;

  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.roles = const [],
    this.workspaces = const [],
    this.driverApplication,
    this.nurseryId,
    this.ownedNurseryStatus,
    this.activeRole,
    this.error,
    this.suspensionInfo,
  });

  SessionState copyWith({
    SessionStatus? status,
    UserProfile? user,
    List<AppRole>? roles,
    List<Workspace>? workspaces,
    DriverApplicationStatus? driverApplication,
    int? nurseryId,
    String? ownedNurseryStatus,
    AppRole? activeRole,
    bool clearActiveRole = false,
    AppError? error,
    SuspensionInfo? suspensionInfo,
    bool clearSuspensionInfo = false,
  }) =>
      SessionState(
        status: status ?? this.status,
        user: user ?? this.user,
        roles: roles ?? this.roles,
        workspaces: workspaces ?? this.workspaces,
        driverApplication: driverApplication ?? this.driverApplication,
        nurseryId: nurseryId ?? this.nurseryId,
        ownedNurseryStatus: ownedNurseryStatus ?? this.ownedNurseryStatus,
        activeRole: clearActiveRole ? null : (activeRole ?? this.activeRole),
        error: error,
        suspensionInfo: clearSuspensionInfo
            ? null
            : (suspensionInfo ?? this.suspensionInfo),
      );

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isLoading => status == SessionStatus.loading;
  bool get isSuspended => status == SessionStatus.suspended;

  /// Bootstrap failed only because the device is offline or the server is
  /// unreachable: the stored session is kept, so the app can retry.
  bool get isOffline => error is NetworkError || error is TimeoutError;

  // V1 workspace helpers — PERSONAL is the default customer context, not a
  // selectable workspace. Only OWNED_NURSERY, MANAGER_NURSERY, DRIVER show.
  List<Workspace> get mobileWorkspaces =>
      workspaces.where((w) => w.isBusinessWorkspace).toList();

  bool get hasMultipleWorkspaces => mobileWorkspaces.length > 1;
  bool get hasCompletedOnboarding => user?.onboardingCompleted ?? false;
  bool get hasPendingDriverApplication => driverApplication?.isPending ?? false;
  bool get hasRejectedDriverApplication =>
      driverApplication?.isRejected ?? false;

  UserCapabilities get capabilities => UserCapabilities.fromWorkspaces(
        workspaces,
        ownedNurseryStatus: ownedNurseryStatus,
        activeRole: activeRole,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  final AuthRepository _repo;

  SessionNotifier(this._repo) : super(const SessionState()) {
    // Wire the interceptor callback so a mid-session membership revocation (403
    // not_member) immediately logs the user out instead of waiting for JWT expiry.
    try {
      ApiClient.authInterceptor.onMembershipRevoked = _onMembershipRevoked;
      ApiClient.authInterceptor.onAccountSuspended = _onAccountSuspended;
      ApiClient.authInterceptor.onSessionExpired = _onSessionExpired;
    } catch (_) {
      // ApiClient not yet initialized in tests — safe to ignore.
    }
  }

  void _onMembershipRevoked() {
    Future.microtask(() async {
      if (state.status == SessionStatus.authenticated) {
        await logout();
      }
    });
  }

  // The refresh token was refused (expired, revoked, signed out elsewhere):
  // storage is already cleared; send the user to login.
  void _onSessionExpired() {
    Future.microtask(() {
      if (state.status == SessionStatus.authenticated) {
        state = const SessionState(status: SessionStatus.unauthenticated);
      }
    });
  }

  void _onAccountSuspended(
      {String? reason, DateTime? suspendedAt, bool nursery = false,}) {
    Future.microtask(() {
      if (state.status == SessionStatus.authenticated ||
          state.status == SessionStatus.loading) {
        state = state.copyWith(
          status: SessionStatus.suspended,
          suspensionInfo: SuspensionInfo(
            reason: reason,
            suspendedAt: suspendedAt,
            nursery: nursery,
          ),
        );
      }
    });
  }

  Future<void> bootstrap() async {
    final previous = state;
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final hasSession = await _repo.hasValidSession();
      if (!hasSession) {
        state = state.copyWith(status: SessionStatus.unauthenticated);
        return;
      }

      // Silently refresh the JWT so any backend-side role changes (e.g. nursery
      // approval granting NURSERY_OWNER) are reflected before role-gated API
      // calls are made. Errors are swallowed — the existing token is used as
      // fallback and login is triggered if it has also expired.
      await _repo.silentRefreshToken();

      final user = await _repo.getCurrentUser();
      final workspaces = await _repo.getWorkspaces();
      final driverApplication = await _repo.getDriverApplicationStatus();
      final roles = await _repo.getUserRoles(workspaces);
      final nurseryId = AuthRepository.nurseryIdOf(workspaces);
      final storedActiveRole = await _repo.getStoredActiveRole();
      final mobileRoles = workspaces
          .where((w) => w.isBusinessWorkspace)
          .map((w) => w.appRole)
          .toSet();
      final activeRole =
          storedActiveRole != null && mobileRoles.contains(storedActiveRole)
              ? storedActiveRole
              : null;

      // Use nursery_status from workspace response (API v2); fallback to separate call for older API builds
      String? ownedNurseryStatus;
      final ownedWorkspace =
          workspaces.where((w) => w.type == 'OWNED_NURSERY').firstOrNull;
      if (ownedWorkspace != null) {
        ownedNurseryStatus =
            ownedWorkspace.nurseryStatus ?? await _repo.getOwnedNurseryStatus();
      }

      state = SessionState(
        status: SessionStatus.authenticated,
        user: user,
        roles: roles,
        workspaces: workspaces,
        driverApplication: driverApplication,
        nurseryId: nurseryId,
        ownedNurseryStatus: ownedNurseryStatus,
        activeRole: activeRole,
      );
    } on AccountSuspendedError catch (e) {
      state = state.copyWith(
        status: SessionStatus.suspended,
        suspensionInfo: SuspensionInfo(
          reason: e.reason,
          suspendedAt: e.suspendedAt,
          nursery: e.nursery,
        ),
      );
    } on UnauthorizedError {
      await _repo.logout();
      state = state.copyWith(status: SessionStatus.unauthenticated);
    } on AppError catch (e) {
      // Already signed in (app resumed, a refresh) and the server is just out
      // of reach: stay in the app. Sending the user to login for a network
      // blip — e.g. right after Razorpay checkout — looked like a logout.
      final transient = e is NetworkError ||
          e is TimeoutError ||
          (e is ServerError && e.statusCode >= 500);
      if (transient && previous.status == SessionStatus.authenticated) {
        state = previous;
        return;
      }
      state = state.copyWith(status: SessionStatus.unauthenticated, error: e);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  void updateUser(UserProfile user) {
    state = state.copyWith(user: user);
  }

  void setActiveRole(AppRole? role) {
    state = state.copyWith(activeRole: role, clearActiveRole: role == null);
  }

  void setSuspended(
      {String? reason, DateTime? suspendedAt, bool nursery = false,}) {
    state = state.copyWith(
      status: SessionStatus.suspended,
      suspensionInfo: SuspensionInfo(
          reason: reason, suspendedAt: suspendedAt, nursery: nursery,),
    );
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref.watch(authRepositoryProvider));
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final session = ref.watch(sessionProvider);
  final activeRole = ref.watch(activeRoleProvider);
  return PermissionService(roles: session.roles, activeRole: activeRole);
});
