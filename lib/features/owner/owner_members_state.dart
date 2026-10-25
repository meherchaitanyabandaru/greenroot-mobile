part of 'owner_members_screen.dart';

class NurseryDriver {
  final int id;
  final int driverUserId;
  final String? name;
  final String? mobile;
  final String connectionStatus;

  const NurseryDriver({
    required this.id,
    required this.driverUserId,
    this.name,
    this.mobile,
    required this.connectionStatus,
  });

  factory NurseryDriver.fromJson(Map<String, dynamic> json) {
    return NurseryDriver(
      id: (json['id'] as num).toInt(),
      driverUserId: (json['driver_user_id'] as num?)?.toInt() ??
          (json['user_id'] as num?)?.toInt() ??
          0,
      name: json['name'] as String? ?? json['full_name'] as String?,
      mobile: json['mobile'] as String?,
      connectionStatus: json['connection_status'] as String? ?? 'CONNECTED',
    );
  }

  String get displayName => name?.trim().isNotEmpty == true ? name! : 'Driver';
}

class NurseryManager {
  final int id;
  final int userId;
  final String? name;
  final String? lastName;
  final String? fullName;
  final String? mobile;
  final String? email;
  final String role;

  const NurseryManager({
    required this.id,
    required this.userId,
    this.name,
    this.lastName,
    this.fullName,
    this.mobile,
    this.email,
    required this.role,
  });

  factory NurseryManager.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] as String?;
    final lastName = json['last_name'] as String?;
    final fullName = json['full_name'] as String?;
    return NurseryManager(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? fullName ?? firstName,
      lastName: lastName,
      fullName: fullName,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      role:
          json['role'] as String? ?? json['role_code'] as String? ?? 'MANAGER',
    );
  }

  String get displayName {
    final trimmedFullName = fullName?.trim();
    if (trimmedFullName?.isNotEmpty == true) return trimmedFullName!;
    final parts = [
      if (name?.trim().isNotEmpty == true) name!.trim(),
      if (lastName?.trim().isNotEmpty == true) lastName!.trim(),
    ];
    final combined = parts.join(' ').trim();
    return combined.isNotEmpty ? combined : 'Manager';
  }

  String get identityLabel {
    // Mobile (or email) identifies a person to the nursery; the internal
    // id only when there is neither.
    final parts = <String>[];
    final trimmedMobile = mobile?.trim();
    final trimmedEmail = email?.trim();
    if (trimmedMobile?.isNotEmpty == true) {
      parts.add(trimmedMobile!);
    } else if (trimmedEmail?.isNotEmpty == true) {
      parts.add(trimmedEmail!);
    }
    return parts.isEmpty ? 'User #$userId' : parts.join(' | ');
  }
}

class NurseryCustomer {
  final int userId;
  final String firstName;
  final String? lastName;
  final String? fullName;
  final String mobile;
  final String? email;
  final DateTime? acceptedAt;

  const NurseryCustomer({
    required this.userId,
    required this.firstName,
    this.lastName,
    this.fullName,
    required this.mobile,
    this.email,
    this.acceptedAt,
  });

  factory NurseryCustomer.fromJson(Map<String, dynamic> json) {
    return NurseryCustomer(
      userId: (json['user_id'] as num).toInt(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      fullName: json['full_name'] as String?,
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String?,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'] as String)
          : null,
    );
  }

  String get displayName {
    final trimmedFullName = fullName?.trim();
    if (trimmedFullName?.isNotEmpty == true) return trimmedFullName!;
    final parts = [
      if (firstName.trim().isNotEmpty) firstName.trim(),
      if (lastName?.trim().isNotEmpty == true) lastName!.trim(),
    ];
    final combined = parts.join(' ').trim();
    if (combined.isNotEmpty) return combined;
    final trimmedName = firstName.trim();
    return trimmedName.isNotEmpty ? trimmedName : 'Customer';
  }

  String get identityLabel {
    // Mobile (or email) identifies a person to the nursery; the internal
    // id only when there is neither.
    final parts = <String>[];
    final trimmedMobile = mobile.trim();
    final trimmedEmail = email?.trim();
    if (trimmedMobile.isNotEmpty) {
      parts.add(trimmedMobile);
    } else if (trimmedEmail?.isNotEmpty == true) {
      parts.add(trimmedEmail!);
    }
    return parts.isEmpty ? 'User #$userId' : parts.join(' | ');
  }
}

class NurseryInvite {
  final int id;
  final String uuid;
  final String inviteType;
  final String status;
  final String? targetName;
  final String? targetMobile;
  final String? targetEmail;
  final DateTime createdAt;

  const NurseryInvite({
    required this.id,
    required this.uuid,
    required this.inviteType,
    required this.status,
    this.targetName,
    this.targetMobile,
    this.targetEmail,
    required this.createdAt,
  });

  factory NurseryInvite.fromJson(Map<String, dynamic> json) {
    return NurseryInvite(
      id: (json['id'] as num).toInt(),
      uuid: json['invite_uuid'] as String? ?? json['uuid'] as String? ?? '',
      inviteType: json['invite_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      targetName: json['target_name'] as String?,
      targetMobile: json['target_mobile'] as String?,
      targetEmail: json['target_email'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
}

// ── State ─────────────────────────────────────────────────────────────────────

class MembersState {
  final bool isLoading;
  final List<NurseryManager> managers;
  final List<NurseryInvite> invites;
  final List<NurseryCustomer> customers;
  final List<NurseryDriver> drivers;
  final String? error;

  const MembersState({
    this.isLoading = false,
    this.managers = const [],
    this.invites = const [],
    this.customers = const [],
    this.drivers = const [],
    this.error,
  });

  MembersState copyWith({
    bool? isLoading,
    List<NurseryManager>? managers,
    List<NurseryInvite>? invites,
    List<NurseryCustomer>? customers,
    List<NurseryDriver>? drivers,
    String? error,
  }) =>
      MembersState(
        isLoading: isLoading ?? this.isLoading,
        managers: managers ?? this.managers,
        invites: invites ?? this.invites,
        customers: customers ?? this.customers,
        drivers: drivers ?? this.drivers,
        error: error,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class MembersNotifier extends StateNotifier<MembersState> {
  final int nurseryId;
  final ApiClient _client;

  MembersNotifier(this.nurseryId, this._client) : super(const MembersState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _client.get<List<NurseryManager>>(
          ApiConstants.nurseryManagers(nurseryId),
          fromJson: (json) {
            final map = json as Map<String, dynamic>;
            final list = map['managers'] as List<dynamic>? ??
                map['users'] as List<dynamic>? ??
                [];
            return list
                .cast<Map<String, dynamic>>()
                .map(NurseryManager.fromJson)
                .toList();
          },
        ),
        _client.get<List<NurseryInvite>>(
          ApiConstants.nurseryInvites(nurseryId),
          fromJson: (json) {
            final list =
                (json as Map<String, dynamic>)['invites'] as List<dynamic>? ??
                    [];
            return list
                .cast<Map<String, dynamic>>()
                .map(NurseryInvite.fromJson)
                .toList();
          },
        ),
        _client.get<List<NurseryCustomer>>(
          ApiConstants.nurseryCustomers(nurseryId),
          fromJson: (json) {
            final list =
                (json as Map<String, dynamic>)['customers'] as List<dynamic>? ??
                    [];
            return list
                .cast<Map<String, dynamic>>()
                .map(NurseryCustomer.fromJson)
                .toList();
          },
        ),
        _client.get<List<NurseryDriver>>(
          ApiConstants.nurseryDrivers(nurseryId),
          fromJson: (json) {
            final map = json as Map<String, dynamic>;
            final list = map['drivers'] as List<dynamic>? ?? [];
            return list
                .cast<Map<String, dynamic>>()
                .map(NurseryDriver.fromJson)
                .toList();
          },
        ),
      ]);
      state = state.copyWith(
        isLoading: false,
        managers: results[0] as List<NurseryManager>,
        invites: results[1] as List<NurseryInvite>,
        customers: results[2] as List<NurseryCustomer>,
        drivers: results[3] as List<NurseryDriver>,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load members');
    }
  }

  Future<bool> removeManager(int userId) async {
    try {
      await _client
          .delete(ApiConstants.removeNurseryManager(nurseryId, userId));
      await load();
      return true;
    } on AppError catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Failed to remove manager');
      return false;
    }
  }

  Future<bool> disconnectDriver(int driverUserId) async {
    try {
      await _client
          .delete(ApiConstants.disconnectDriver(nurseryId, driverUserId));
      await load();
      return true;
    } on AppError catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Failed to disconnect driver');
      return false;
    }
  }

  Future<NurseryInvite?> createInvite({
    required String inviteType,
    required String targetMobile,
    String? targetName,
  }) async {
    try {
      final invite = await _client.post<NurseryInvite>(
        ApiConstants.invites,
        data: {
          'invite_type': inviteType,
          'nursery_id': nurseryId,
          'target_mobile': targetMobile,
          if (targetName != null && targetName.isNotEmpty)
            'target_name': targetName,
        },
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          final invJson = map['invite'] as Map<String, dynamic>? ?? map;
          return NurseryInvite.fromJson(invJson);
        },
      );
      await load();
      return invite;
    } on AppError catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create invite');
      return null;
    }
  }
}

// ── Provider factory ──────────────────────────────────────────────────────────

final membersProvider =
    StateNotifierProvider.family<MembersNotifier, MembersState, int>(
  (ref, nurseryId) => MembersNotifier(nurseryId, ApiClient.instance),
);

// ── Screen ────────────────────────────────────────────────────────────────────
