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
      // V1: derive roles from workspace API (source of truth for role-based routing)
      final workspaces = await _remote.getWorkspaces();
      final roles = <AppRole>{};
      for (final ws in workspaces) {
        final type = ws['type'] as String? ?? '';
        switch (type) {
          case 'OWNED_NURSERY':
            roles.add(AppRole.nurseryOwner);
          case 'MANAGER_NURSERY':
            roles.add(AppRole.manager);
          case 'DRIVER':
            roles.add(AppRole.driver);
          case 'PERSONAL':
            // Only add BUYER if no other role was found (handled below)
            break;
        }
      }
      // Fall back to BUYER if nothing else applies
      if (roles.isEmpty) roles.add(AppRole.buyer);

      // Also pick up ADMIN/SUPER_ADMIN from the old roles endpoint as a supplement
      try {
        final userId = await SecureStorageService.getUserId();
        if (userId != null) {
          final response = await _remote.getUserRoles(userId);
          for (final r in response.roles) {
            final role = AppRole.fromString(r.role);
            if (role == AppRole.admin || role == AppRole.superAdmin) {
              roles.add(role!);
            }
          }
        }
      } catch (_) {}

      AppLogger.i('Resolved roles from workspaces: ${roles.map((r) => r.value).join(', ')}');
      return roles.toList();
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('getUserRoles error', e);
      throw const UnknownError();
    }
  }

  Future<int?> getNurseryId() async {
    try {
      final workspaces = await _remote.getWorkspaces();
      for (final ws in workspaces) {
        if (ws['type'] == 'OWNED_NURSERY' || ws['type'] == 'MANAGER_NURSERY') {
          final id = ws['nursery_id'];
          if (id != null) return (id as num).toInt();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Workspace>> getWorkspaces() async {
    try {
      final raw = await _remote.getWorkspaces();
      return raw.map(Workspace.fromJson).toList();
    } catch (_) {
      return [];
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
  }) async {
    try {
      await _remote.createNursery(
        name: name,
        mobile: mobile,
        email: email,
        description: description,
      );
      AppLogger.i('Nursery registration submitted: $name');
    } on AppError {
      rethrow;
    } catch (e) {
      AppLogger.e('registerNursery error', e);
      throw const UnknownError();
    }
  }
}
