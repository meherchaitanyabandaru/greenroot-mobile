import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_models.dart';
import '../models/user_models.dart';

class AuthRemoteDataSource {
  final ApiClient _client;

  const AuthRemoteDataSource(this._client);

  Future<SendOtpResponse> sendOtp(String mobile) => _client.post(
        ApiConstants.sendOtp,
        data: SendOtpRequest(mobile: mobile).toJson(),
        fromJson: (json) =>
            SendOtpResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<AuthResponse> verifyOtp(String mobile, String otp) => _client.post(
        ApiConstants.verifyOtp,
        data: VerifyOtpRequest(mobile: mobile, otp: otp).toJson(),
        fromJson: (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<AuthResponse> refreshToken(String refreshToken) => _client.post(
        ApiConstants.refreshToken,
        data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
        fromJson: (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<void> logout(String? refreshToken) => _client.post(
        ApiConstants.logout,
        data: LogoutRequest(refreshToken: refreshToken).toJson(),
      );

  Future<UserProfile> getMe() => _client.get(
        ApiConstants.usersMe,
        fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
      );

  Future<UserRolesResponse> getUserRoles(int userId) => _client.get(
        ApiConstants.userRoles(userId),
        fromJson: (json) =>
            UserRolesResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<List<Map<String, dynamic>>> getWorkspaces() => _client.get(
        ApiConstants.myWorkspaces,
        fromJson: (json) {
          // API returns a bare JSON array, not {"workspaces": [...]}
          if (json is List) return json.cast<Map<String, dynamic>>();
          final list =
              (json as Map<String, dynamic>)['workspaces'] as List<dynamic>? ??
                  [];
          return list.cast<Map<String, dynamic>>();
        },
      );

  Future<UserProfile> updateProfile(int userId, UpdateProfileRequest req) =>
      _client.put(
        ApiConstants.usersMe,
        data: req.toJson(),
        fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
      );

  Future<UserProfile> completeOnboarding(String initialActivity) =>
      _client.post(
        ApiConstants.usersMeOnboarding,
        data: {'initial_activity': initialActivity},
        fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
      );

  Future<DriverApplicationStatus> getDriverApplicationStatus() => _client.get(
        ApiConstants.driversMe,
        fromJson: (json) =>
            DriverApplicationStatus.fromJson(json as Map<String, dynamic>),
      );

  Future<String?> getOwnedNurseryStatus() async {
    try {
      final data = await _client.get<Map<String, dynamic>>(
        '${ApiConstants.nurseries}/owned',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      final nursery = data['nursery'] as Map<String, dynamic>?;
      return nursery?['status'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOwnedNursery() async {
    try {
      final data = await _client.get<Map<String, dynamic>>(
        '${ApiConstants.nurseries}/owned',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      return data['nursery'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> createNursery({
    required String name,
    String? mobile,
    String? email,
    String? description,
    String? addressLine1,
    String? city,
    String? state,
    String? postalCode,
  }) =>
      _client.post(
        ApiConstants.nurseries,
        data: {
          'name': name,
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (email != null && email.isNotEmpty) 'email': email,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (addressLine1 != null && addressLine1.isNotEmpty)
            'address_line1': addressLine1,
          if (city != null && city.isNotEmpty) 'city': city,
          if (state != null && state.isNotEmpty) 'state': state,
          if (postalCode != null && postalCode.isNotEmpty)
            'postal_code': postalCode,
          'status': 'PENDING',
        },
      );
}
