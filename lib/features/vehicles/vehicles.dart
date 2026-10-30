import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

// A driver's lorries. A lorry and its owner are records of their own: the
// owner needs no GreenRoot account, many drivers may drive one lorry and one
// driver may drive lorries of different owners. GreenRoot approves each link.

/// Lorry types a trip can ask for (the API's codes).
const lorryTypes = ['TRUCK', 'VAN', 'PICKUP', 'AUTO'];

String lorryTypeLabel(String? type) => type == null || type.isEmpty
    ? 'Lorry'
    : type[0] + type.substring(1).toLowerCase().replaceAll('_', ' ');

/// Why a lorry cannot take a trip now, for the driver. Same codes as the API.
String lorryBlockedText(String? reason) => switch (reason) {
      'LINK_PENDING' => 'Waiting for GreenRoot to approve you for this lorry.',
      'LINK_SUSPENDED' =>
        'Your link to this lorry is suspended. Contact GreenRoot support.',
      'VEHICLE_NOT_APPROVED' => 'Waiting for GreenRoot to approve this lorry.',
      'VEHICLE_MAINTENANCE' => 'This lorry is marked under maintenance.',
      'VEHICLE_INACTIVE' => 'This lorry is not active.',
      'LICENCE_EXPIRED' =>
        'Your driving licence has expired. Update it before taking trips.',
      'VEHICLE_ON_TRIP' => 'This lorry is already on another trip.',
      'VEHICLE_TYPE_MISMATCH' => 'This trip needs a different type of lorry.',
      _ => 'This lorry cannot take trips now.',
    };

/// One of the driver's lorries. From GET /drivers/me/vehicles (all fields)
/// or a trip preview's driver_vehicles (vehicle and eligibility only).
class Lorry {
  final int vehicleId;
  final String vehicleNumber;
  final String? vehicleType;
  final double? capacityKg;
  final bool isEligible;
  final String? blockedReason;
  final String? blockedMessage;
  final int? linkId;
  final String? linkStatus;
  final String? ownerName;
  final bool isOwner;

  const Lorry({
    required this.vehicleId,
    required this.vehicleNumber,
    this.vehicleType,
    this.capacityKg,
    required this.isEligible,
    this.blockedReason,
    this.blockedMessage,
    this.linkId,
    this.linkStatus,
    this.ownerName,
    this.isOwner = false,
  });

  factory Lorry.fromJson(Map<String, dynamic> j) => Lorry(
        vehicleId: (j['vehicle_id'] as num).toInt(),
        vehicleNumber: j['vehicle_number'] as String,
        vehicleType: j['vehicle_type'] as String?,
        capacityKg: (j['capacity_kg'] as num?)?.toDouble(),
        isEligible: j['is_eligible'] == true,
        blockedReason: j['blocked_reason'] as String?,
        blockedMessage: j['blocked_message'] as String?,
        linkId: (j['link_id'] as num?)?.toInt(),
        linkStatus: j['link_status'] as String?,
        ownerName: j['owner_name'] as String?,
        isOwner: j['is_owner'] == true,
      );

  /// The API's text when it sent one, else ours for the code.
  String get blockedText => blockedMessage ?? lorryBlockedText(blockedReason);
}

/// Who owns a lorry the driver adds: themselves, or someone else by name
/// (mobile optional: the owner does not need the app).
class LorryOwner {
  final bool isMe;
  final String name;
  final String mobile;
  const LorryOwner.me()
      : isMe = true,
        name = '',
        mobile = '';
  const LorryOwner.other(this.name, this.mobile) : isMe = false;

  Map<String, dynamic> toJson() => isMe
      ? {'is_owner': true}
      : {
          'is_owner': false,
          'owner_name': name.trim(),
          if (mobile.trim().isNotEmpty) 'owner_mobile': mobile.trim(),
        };
}

class LorryRepository {
  final ApiClient _client;
  LorryRepository(this._client);

  Future<List<Lorry>> myLorries() => _client.get(
        ApiConstants.driverVehicles,
        fromJson: (data) => ((data as Map<String, dynamic>)['vehicles']
                as List<dynamic>)
            .map((e) => Lorry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<Lorry> addLorry({
    required String vehicleNumber,
    required String vehicleType,
    double? capacityKg,
    required LorryOwner owner,
  }) =>
      _client.post(
        ApiConstants.driverVehicles,
        data: {
          'vehicle_number': vehicleNumber,
          'vehicle_type': vehicleType,
          if (capacityKg != null) 'capacity_kg': capacityKg,
          ...owner.toJson(),
        },
        fromJson: (data) => Lorry.fromJson(
            (data as Map<String, dynamic>)['vehicle'] as Map<String, dynamic>,),
      );

  Future<void> removeLorry(int linkId) =>
      _client.delete<dynamic>(ApiConstants.driverVehicle(linkId));
}

final lorryRepositoryProvider =
    Provider<LorryRepository>((ref) => LorryRepository(ApiClient.instance));

final myLorriesProvider = FutureProvider.autoDispose<List<Lorry>>(
  (ref) => ref.watch(lorryRepositoryProvider).myLorries(),
);
