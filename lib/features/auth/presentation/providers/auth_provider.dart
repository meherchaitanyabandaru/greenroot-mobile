import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/rbac/roles.dart';

// ── Repository provider ────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = AuthRemoteDataSource(ApiClient.instance);
  return AuthRepository(dataSource);
});

// ── OTP send state ─────────────────────────────────────────────────────────
class OtpSendState {
  final bool isLoading;
  final bool sent;
  final AppError? error;

  const OtpSendState({
    this.isLoading = false,
    this.sent = false,
    this.error,
  });

  OtpSendState copyWith({bool? isLoading, bool? sent, AppError? error}) =>
      OtpSendState(
        isLoading: isLoading ?? this.isLoading,
        sent:      sent      ?? this.sent,
        error:     error,
      );
}

class OtpSendNotifier extends StateNotifier<OtpSendState> {
  final AuthRepository _repo;
  String? _lastMobile;

  OtpSendNotifier(this._repo) : super(const OtpSendState());

  String? get lastMobile => _lastMobile;

  Future<void> sendOtp(String mobile) async {
    state = const OtpSendState(isLoading: true);
    try {
      await _repo.sendOtp(mobile);
      _lastMobile = mobile;
      state = const OtpSendState(sent: true);
    } on AppError catch (e) {
      state = OtpSendState(error: e);
    }
  }

  void reset() => state = const OtpSendState();
}

final otpSendProvider =
    StateNotifierProvider<OtpSendNotifier, OtpSendState>((ref) {
  return OtpSendNotifier(ref.watch(authRepositoryProvider));
});

// ── OTP verify state ───────────────────────────────────────────────────────
class OtpVerifyState {
  final bool isLoading;
  final bool verified;
  final AppError? error;

  const OtpVerifyState({
    this.isLoading = false,
    this.verified = false,
    this.error,
  });

  OtpVerifyState copyWith({bool? isLoading, bool? verified, AppError? error}) =>
      OtpVerifyState(
        isLoading: isLoading ?? this.isLoading,
        verified:  verified  ?? this.verified,
        error:     error,
      );
}

class OtpVerifyNotifier extends StateNotifier<OtpVerifyState> {
  final AuthRepository _repo;

  OtpVerifyNotifier(this._repo) : super(const OtpVerifyState());

  Future<void> verify(String mobile, String otp) async {
    state = const OtpVerifyState(isLoading: true);
    try {
      await _repo.verifyOtp(mobile, otp);
      state = const OtpVerifyState(verified: true);
    } on AppError catch (e) {
      state = OtpVerifyState(error: e);
    }
  }

  void reset() => state = const OtpVerifyState();
}

final otpVerifyProvider =
    StateNotifierProvider<OtpVerifyNotifier, OtpVerifyState>((ref) {
  return OtpVerifyNotifier(ref.watch(authRepositoryProvider));
});

// ── Role selection state ───────────────────────────────────────────────────
class RoleSelectionNotifier extends StateNotifier<AppRole?> {
  final AuthRepository _repo;

  RoleSelectionNotifier(this._repo) : super(null);

  Future<void> loadSavedRole() async {
    state = await _repo.getStoredActiveRole();
  }

  Future<void> selectRole(AppRole role) async {
    await _repo.saveActiveRole(role);
    state = role;
  }
}

final activeRoleProvider =
    StateNotifierProvider<RoleSelectionNotifier, AppRole?>((ref) {
  return RoleSelectionNotifier(ref.watch(authRepositoryProvider));
});
