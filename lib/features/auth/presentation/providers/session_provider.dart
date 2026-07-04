import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/models/capabilities_model.dart';
import '../../data/models/user_models.dart';
import '../../data/models/workspace_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/rbac/permission_service.dart';
import '../../domain/rbac/roles.dart';
import 'auth_provider.dart';

enum SessionStatus { unknown, loading, authenticated, unauthenticated }

class SessionState {
  final SessionStatus status;
  final UserProfile? user;
  final List<AppRole> roles;
  final List<Workspace> workspaces;
  final int? nurseryId;
  final String? ownedNurseryStatus;
  final AppRole? activeRole;
  final AppError? error;

  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.roles = const [],
    this.workspaces = const [],
    this.nurseryId,
    this.ownedNurseryStatus,
    this.activeRole,
    this.error,
  });

  SessionState copyWith({
    SessionStatus? status,
    UserProfile? user,
    List<AppRole>? roles,
    List<Workspace>? workspaces,
    int? nurseryId,
    String? ownedNurseryStatus,
    AppRole? activeRole,
    bool clearActiveRole = false,
    AppError? error,
  }) =>
      SessionState(
        status: status ?? this.status,
        user: user ?? this.user,
        roles: roles ?? this.roles,
        workspaces: workspaces ?? this.workspaces,
        nurseryId: nurseryId ?? this.nurseryId,
        ownedNurseryStatus: ownedNurseryStatus ?? this.ownedNurseryStatus,
        activeRole: clearActiveRole ? null : (activeRole ?? this.activeRole),
        error: error,
      );

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isLoading => status == SessionStatus.loading;

  // V1 workspace helpers — PERSONAL is the default customer context, not a
  // selectable workspace. Only OWNED_NURSERY, MANAGER_NURSERY, DRIVER show.
  List<Workspace> get mobileWorkspaces =>
      workspaces.where((w) => w.isBusinessWorkspace).toList();

  bool get hasMultipleWorkspaces => mobileWorkspaces.length > 1;

  UserCapabilities get capabilities => UserCapabilities.fromWorkspaces(
        workspaces,
        ownedNurseryStatus: ownedNurseryStatus,
        activeRole: activeRole,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  final AuthRepository _repo;

  SessionNotifier(this._repo) : super(const SessionState());

  Future<void> bootstrap() async {
    state = state.copyWith(status: SessionStatus.loading);
    try {
      final hasSession = await _repo.hasValidSession();
      if (!hasSession) {
        state = state.copyWith(status: SessionStatus.unauthenticated);
        return;
      }

      final user = await _repo.getCurrentUser();
      final workspaces = await _repo.getWorkspaces();
      final roles = await _repo.getUserRoles();
      final nurseryId = await _repo.getNurseryId();
      final storedActiveRole = await _repo.getStoredActiveRole();
      final mobileRoles = workspaces
          .where((w) => w.isBusinessWorkspace)
          .map((w) => w.appRole)
          .toSet();
      final activeRole =
          storedActiveRole != null && mobileRoles.contains(storedActiveRole)
              ? storedActiveRole
              : null;

      // Fetch nursery status separately for pending/rejected routing
      String? ownedNurseryStatus;
      final hasOwnedNursery = workspaces.any((w) => w.type == 'OWNED_NURSERY');
      if (hasOwnedNursery) {
        ownedNurseryStatus = await _repo.getOwnedNurseryStatus();
      }

      state = SessionState(
        status: SessionStatus.authenticated,
        user: user,
        roles: roles,
        workspaces: workspaces,
        nurseryId: nurseryId,
        ownedNurseryStatus: ownedNurseryStatus,
        activeRole: activeRole,
      );
    } on UnauthorizedError {
      await _repo.logout();
      state = state.copyWith(status: SessionStatus.unauthenticated);
    } on AppError catch (e) {
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
