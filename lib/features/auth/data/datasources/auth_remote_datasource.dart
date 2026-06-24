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
        fromJson: (json) => SendOtpResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<AuthResponse> verifyOtp(String mobile, String otp) => _client.post(
        ApiConstants.verifyOtp,
        data: VerifyOtpRequest(mobile: mobile, otp: otp).toJson(),
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
        fromJson: (json) => UserRolesResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<UserProfile> updateProfile(int userId, UpdateProfileRequest req) =>
      _client.put(
        ApiConstants.usersMe,
        data: req.toJson(),
        fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
      );
}
