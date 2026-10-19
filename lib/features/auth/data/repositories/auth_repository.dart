import '../../../../core/errors/app_error.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utilities/logger.dart';
import '../../domain/rbac/roles.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_models.dart';
import '../models/user_models.dart';
import '../models/workspace_model.dart';

class AuthRepository {
  final AuthRemoteDataSource _remote;

  const AuthRepository(this._remote);

  Future<void> sendOtp(String mobile) async {
    try {
      await _remote.sendOtp(mobile);
      AppLogger.i('OTP sent to $mobile');
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('sendOtp error', e);
      throw const UnknownError();
    }
  }

  Future<AuthResponse> verifyOtp(String mobile, String otp) async {
    try {
      final response = await _remote.verifyOtp(mobile, otp);
      await SecureStorageService.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.user.id,
      );
      AppLogger.i('Login success — userId=${response.user.id}');
      return response;
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('verifyOtp error', e);
      throw const UnknownError();
    }
  }

  /// Silently exchanges the stored refresh token for a new access + refresh token
  /// pair. The new tokens are persisted to secure storage. Called at session
  /// bootstrap so that any backend-side role changes (e.g. nursery approval) are
  /// reflected in the JWT before the first role-gated API call is made.
  ///
  /// Errors are swallowed (network down, token expired): the existing tokens
  /// stay and bootstrap carries on. A suspension is rethrown with its reason.
  Future<void> silentRefreshToken() async {
    try {
      final existing = await SecureStorageService.getRefreshToken();
      if (existing == null) return;
      final response = await _remote.refreshToken(existing);
      await SecureStorageService.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.user.id,
      );
      AppLogger.i('Silent token refresh succeeded — roles updated in JWT');
    } on AccountSuspendedError {
      // Only this response carries the suspension reason and date: pass it on
      // so the suspended screen can show them.
      rethrow;
    } catch (e) {
      AppLogger.w(
          'Silent token refresh failed (continuing with existing token)', e,);
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      await _remote.logout(refreshToken);
    } catch (e) {
      AppLogger.w('Logout API failed (ignoring)', e);
    } finally {
      await SecureStorageService.clearSession();
    }
  }

  Future<UserProfile> getCurrentUser() async {
    try {
      return await _remote.getMe();
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('getCurrentUser error', e);
      throw const UnknownError();
    }
  }

  /// Business roles come from the workspaces (owner, manager, driver);
  /// everyone else is a buyer. ADMIN/SUPER_ADMIN come from the roles endpoint.
  Future<List<AppRole>> getUserRoles(List<Workspace> workspaces) async {
    final roles = {
      for (final ws in workspaces)
        if (ws.isBusinessWorkspace) ws.appRole,
    };
    if (roles.isEmpty) roles.add(AppRole.buyer);
    try {
      final userId = await SecureStorageService.getUserId();
      if (userId != null) {
        final response = await _remote.getUserRoles(userId);
        for (final r in response.roles) {
          final role = AppRole.fromString(r.role);
          if (role == AppRole.admin || role == AppRole.superAdmin) roles.add(role!);
        }
      }
    } catch (_) {
      // Admin roles only add the admin home; business roles above still hold.
    }
    AppLogger.i('Resolved roles: ${roles.map((r) => r.value).join(', ')}');
    return roles.toList();
  }

  /// The nursery the user owns or manages, from the workspaces.
  static int? nurseryIdOf(List<Workspace> workspaces) => workspaces
      .where((w) => w.type == 'OWNED_NURSERY' || w.type == 'MANAGER_NURSERY')
      .map((w) => w.nurseryId)
      .whereType<int>()
      .firstOrNull;

  /// Fails loudly: an empty list would quietly turn an owner into a buyer.
  Future<List<Workspace>> getWorkspaces() async {
    try {
      final raw = await _remote.getWorkspaces();
      return raw.map(Workspace.fromJson).toList();
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('getWorkspaces error', e);
      throw const UnknownError();
    }
  }

  Future<bool> hasValidSession() async {
    return SecureStorageService.hasSession();
  }

  Future<AppRole?> getStoredActiveRole() async {
    final role = await SecureStorageService.getActiveRole();
    return AppRole.fromString(role);
  }

  Future<void> saveActiveRole(AppRole role) async {
    await SecureStorageService.saveActiveRole(role.value);
  }

  /// Emails a 6-digit code proving the user owns [email]. Returns the dev
  /// code in mock mode (null when real email is on).
  Future<String?> sendEmailCode(String email) async {
    try {
      final res = await _remote.sendEmailCode(email);
      return res['mock_code'] as String?;
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('sendEmailCode error', e);
      throw const UnknownError();
    }
  }

  /// Verifies the emailed code; the returned profile has email_verified=true.
  Future<UserProfile> verifyEmail(String email, String code) async {
    try {
      return await _remote.verifyEmail(email, code);
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('verifyEmail error', e);
      throw const UnknownError();
    }
  }

  /// Texts a code to the NEW sign-in number. Returns the dev code in mock mode.
  Future<String?> sendMobileCode(String mobile) async {
    final res = await _remote.sendMobileCode(mobile);
    return res['mock_code'] as String?;
  }

  /// Verifies the code sent to the new number and makes it the sign-in number.
  Future<UserProfile> changeMobile(String mobile, String code) => _remote.changeMobile(mobile, code);

  Future<UserProfile> updateProfile(UpdateProfileRequest req) async {
    try {
      final userId = await SecureStorageService.getUserId();
      if (userId == null) throw const UnauthorizedError();
      return await _remote.updateProfile(userId, req);
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('updateProfile error', e);
      throw const UnknownError();
    }
  }

  Future<UserProfile> completeOnboarding(String initialActivity) async {
    try {
      return await _remote.completeOnboarding(initialActivity);
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('completeOnboarding error', e);
      throw const UnknownError();
    }
  }

  Future<DriverApplicationStatus?> getDriverApplicationStatus() async {
    try {
      return await _remote.getDriverApplicationStatus();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getOwnedNurseryStatus() async {
    try {
      return await _remote.getOwnedNurseryStatus();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOwnedNursery() async {
    try {
      return await _remote.getOwnedNursery();
    } catch (_) {
      return null;
    }
  }

  Future<void> registerNursery({
    required String name,
    String? mobile,
    String? email,
    String? description,
    String? addressLine1,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _remote.createNursery(
        name: name,
        mobile: mobile,
        email: email,
        description: description,
        addressLine1: addressLine1,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
      );
      AppLogger.i('Nursery registration submitted: $name');
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('registerNursery error', e);
      throw const UnknownError();
    }
  }

  Future<void> resubmitNursery({
    required String name,
    String? mobile,
    String? email,
    String? description,
    String? addressLine1,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _remote.resubmitNursery(
        name: name,
        mobile: mobile,
        email: email,
        description: description,
        addressLine1: addressLine1,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
      );
      AppLogger.i('Nursery resubmission submitted: $name');
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('resubmitNursery error', e);
      throw const UnknownError();
    }
  }
}
