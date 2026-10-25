import 'package:flutter/material.dart';

import '../../core/utilities/money.dart';
import 'quotations.dart';

/// Asks the buyer to confirm before accepting a quotation: accepting lets
/// the nursery turn it into an order, so a stray tap must not do it.
Future<bool> confirmAcceptQuotation(BuildContext context, Quotation q) async {
  final nursery = q.nurseryName ?? 'the nursery';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Accept this quotation?'),
      content: Text(
        '${inr(q.totalAmount)} from $nursery. The nursery can then turn it '
        'into your order.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          // The theme makes filled buttons full width; not in a dialog row.
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Accept'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
