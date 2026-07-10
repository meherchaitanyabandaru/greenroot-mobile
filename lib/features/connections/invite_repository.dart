import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class InviteRepository {
  const InviteRepository();

  Future<Map<String, dynamic>> sendInvite({
    required String inviteType,
    required int nurseryId,
    required String? targetMobile,
    String? targetName,
  }) async {
    final data = await ApiClient.instance.post<Map<String, dynamic>>(
      ApiConstants.invites,
      data: {
        'invite_type': inviteType,
        'nursery_id': nurseryId,
        if (targetMobile != null) 'target_mobile': targetMobile,
        if (targetName != null && targetName.isNotEmpty) 'target_name': targetName,
      },
    );
    return (data['invite'] ?? data) as Map<String, dynamic>;
  }
}

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => const InviteRepository(),
);
