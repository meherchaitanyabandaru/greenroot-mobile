class UserProfile {
  final int id;
  final String? userCode;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? mobile;
  final bool mobileVerified;
  final String? email;
  final bool emailVerified;
  final String? profileImageUrl;
  final String? status;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.userCode,
    this.firstName,
    this.lastName,
    this.gender,
    this.mobile,
    this.mobileVerified = false,
    this.email,
    this.emailVerified = false,
    this.profileImageUrl,
    this.status,
    this.createdAt,
  });

  // Convenience getter used throughout the UI
  String? get name {
    final parts = [firstName, lastName]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final u = json['user'] as Map<String, dynamic>? ?? json;
    return UserProfile(
      id:              u['id']                as int,
      userCode:        u['user_code']         as String?,
      firstName:       u['first_name']        as String?,
      lastName:        u['last_name']         as String?,
      gender:          u['gender']            as String?,
      mobile:          u['mobile']            as String?,
      mobileVerified:  u['mobile_verified']   as bool? ?? false,
      email:           u['email']             as String?,
      emailVerified:   u['email_verified']    as bool? ?? false,
      profileImageUrl: u['profile_image_url'] as String?,
      status:          u['status']            as String?,
      createdAt: u['created_at'] != null
          ? DateTime.tryParse(u['created_at'] as String)
          : null,
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? profileImageUrl,
    String? gender,
  }) =>
      UserProfile(
        id: id,
        userCode: userCode,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        gender: gender ?? this.gender,
        mobile: mobile,
        mobileVerified: mobileVerified,
        email: email ?? this.email,
        emailVerified: emailVerified,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        status: status,
        createdAt: createdAt,
      );

  /// True when the user has completed their full profile.
  /// firstName + lastName + gender must all be set.
  bool get isProfileComplete =>
      (firstName?.isNotEmpty ?? false) &&
      (lastName?.isNotEmpty ?? false) &&
      (gender?.isNotEmpty ?? false);

  String get initials {
    final fn = firstName;
    final ln = lastName;
    if (fn == null || fn.isEmpty) return '?';
    if (ln != null && ln.isNotEmpty) return '${fn[0]}${ln[0]}'.toUpperCase();
    return fn[0].toUpperCase();
  }
}

class UserRole {
  final int id;
  final String role;
  final int? nurseryId;
  final String? nurseryName;

  const UserRole({
    required this.id,
    required this.role,
    this.nurseryId,
    this.nurseryName,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) => UserRole(
        id:          json['id']           as int,
        role:        json['code']         as String,  // API returns 'code', not 'role'
        nurseryId:   json['nursery_id']   as int?,
        nurseryName: json['nursery_name'] as String?,
      );
}

class UserRolesResponse {
  final List<UserRole> roles;

  const UserRolesResponse({required this.roles});

  factory UserRolesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['roles'] as List<dynamic>? ?? [];
    return UserRolesResponse(
      roles: list.map((e) => UserRole.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class UpdateProfileRequest {
  final String firstName;
  final String? lastName;
  final String? email;
  final String? gender;
  final String? profileImageUrl;

  const UpdateProfileRequest({
    required this.firstName,
    this.lastName,
    this.email,
    this.gender,
    this.profileImageUrl,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      };
}
