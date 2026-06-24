import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/rbac/permission_service.dart';
import '../../domain/rbac/roles.dart';
import 'auth_provider.dart';

enum SessionStatus { unknown, loading, authenticated, unauthenticated }

class SessionState {
  final SessionStatus status;
  final UserProfile? user;
  final List<AppRole> roles;
  final int? nurseryId;
  final AppError? error;

  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.roles = const [],
    this.nurseryId,
    this.error,
  });

  SessionState copyWith({
    SessionStatus? status,
    UserProfile? user,
    List<AppRole>? roles,
    int? nurseryId,
    AppError? error,
  }) =>
      SessionState(
        status: status ?? this.status,
        user: user ?? this.user,
        roles: roles ?? this.roles,
        nurseryId: nurseryId ?? this.nurseryId,
        error: error,
      );

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isLoading => status == SessionStatus.loading;
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
      final roles = await _repo.getUserRoles();
      final nurseryId = await _repo.getNurseryId();

      state = SessionState(
        status: SessionStatus.authenticated,
        user: user,
        roles: roles,
        nurseryId: nurseryId,
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
