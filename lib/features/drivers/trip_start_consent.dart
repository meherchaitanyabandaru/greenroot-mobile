import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/consent/consent.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dispatches/dispatches.dart';

/// The driver's confirmation before starting [trip] (load, lorry and trip
/// details; accepting the job). Null: they stepped back. An empty map: the
/// trip asks for none (older trips, or someone other than its driver).
Future<Map<String, dynamic>?> startTripConsent(
    BuildContext context, WidgetRef ref, Dispatch trip,) async {
  final me = ref.read(sessionProvider).user?.id;
  if (!trip.requiresConsent || trip.status != 'ACCEPTED' || trip.driverUserId != me) {
    return const {};
  }
  return askConsent(
    context,
    ref,
    ConsentStep.driverDispatch,
    intro: [
      'Trip ${trip.dispatchCode}',
      if (trip.vehicleNumber != null) 'lorry ${trip.vehicleNumber}',
      if (trip.sellerNurseryName != null) 'from ${trip.sellerNurseryName}',
    ].join(' · '),
  );
}

/// What updateStatus sends: no confirmation when none was asked for.
Map<String, dynamic>? consentOrNull(Map<String, dynamic> c) => c.isEmpty ? null : c;
