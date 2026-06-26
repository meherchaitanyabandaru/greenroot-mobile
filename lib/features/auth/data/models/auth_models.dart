class SendOtpRequest {
  final String mobile;
  const SendOtpRequest({required this.mobile});

  Map<String, dynamic> toJson() => {'mobile': mobile};
}

class SendOtpResponse {
  final String message;
  const SendOtpResponse({required this.message});

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) =>
      SendOtpResponse(message: json['message'] as String? ?? '');
}

class VerifyOtpRequest {
  final String mobile;
  final String otp;
  const VerifyOtpRequest({required this.mobile, required this.otp});

  Map<String, dynamic> toJson() => {'mobile': mobile, 'otp': otp};
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserSummary user;
  final bool isNewUser;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.isNewUser = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken:  json['access_token']  as String,
        refreshToken: json['refresh_token'] as String,
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
        isNewUser: json['is_new_user'] as bool? ?? false,
      );
}

class RefreshTokenRequest {
  final String refreshToken;
  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

class LogoutRequest {
  final String? refreshToken;
  const LogoutRequest({this.refreshToken});

  Map<String, dynamic> toJson() => {
        if (refreshToken != null) 'refresh_token': refreshToken,
      };
}

class UserSummary {
  final int id;
  final String? userCode;
  final String? firstName;
  final String? lastName;
  final String? mobile;
  final String? email;
  final String? status;
  final List<String> roles;

  const UserSummary({
    required this.id,
    this.userCode,
    this.firstName,
    this.lastName,
    this.mobile,
    this.email,
    this.status,
    this.roles = const [],
  });

  String? get name {
    final parts = [firstName, lastName]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id:         json['id']          as int,
        userCode:   json['user_code']   as String?,
        firstName:  json['first_name']  as String?,
        lastName:   json['last_name']   as String?,
        mobile:     json['mobile']      as String?,
        email:      json['email']       as String?,
        status:     json['status']      as String?,
        roles: (json['roles'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}
