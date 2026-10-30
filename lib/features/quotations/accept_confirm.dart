import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/consent/consent.dart';
import '../../core/utilities/money.dart';
import 'quotations.dart';

/// Asks the buyer to confirm before accepting a quotation: accepting lets
/// the nursery turn it into an order, so a stray tap must not do it. The
/// buyer ticks what they acknowledge (prices, payment between them and the
/// nursery); returns that confirmation for the API, or null to stay.
Future<Map<String, dynamic>?> confirmAcceptQuotation(
    BuildContext context, WidgetRef ref, Quotation q,) {
  final nursery = q.nurseryName ?? 'the nursery';
  return askConsent(
    context,
    ref,
    ConsentStep.buyerQuotationAccept,
    intro: '${inr(q.totalAmount)} from $nursery. The nursery can then turn it into your order.',
  );
}
