import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utilities/logger.dart';
import '../../domain/rbac/roles.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_models.dart';
import '../models/user_models.dart';

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
        accessToken:  response.accessToken,
        refreshToken: response.refreshToken,
        userId:       response.user.id,
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

  Future<List<AppRole>> getUserRoles() async {
    try {
      final userId = await SecureStorageService.getUserId();
      if (userId == null) throw const UnauthorizedError();

      final response = await _remote.getUserRoles(userId);
      return response.roles
          .map((r) => AppRole.fromString(r.role))
          .whereType<AppRole>()
          .toList();
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('getUserRoles error', e);
      throw const UnknownError();
    }
  }

  Future<int?> getNurseryId() async {
    try {
      return await ApiClient.instance.get(
        ApiConstants.myNurseries,
        fromJson: (data) {
          final list = (data as Map<String, dynamic>)['nurseries'] as List<dynamic>;
          if (list.isEmpty) return null;
          return ((list.first as Map<String, dynamic>)['id'] as num).toInt();
        },
      );
    } catch (_) {
      return null;
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
}
