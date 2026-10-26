import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/domain/workflow.dart';
import 'package:greenroot_mobile/features/quotations/quotations.dart';

import '../helpers/fixtures.dart';

Quotation quote(String status, DateTime validUntil) {
  final j = (fixture('quotation_detail') as Map<String, dynamic>)['quotation']
      as Map<String, dynamic>;
  return Quotation.fromJson({
    ...j,
    'quotation_status': status,
    'status': status,
    'valid_until': validUntil.toUtc().toIso8601String(),
  });
}

void main() {
  final past = DateTime.now().subtract(const Duration(days: 1));
  final future = DateTime.now().add(const Duration(days: 5));

  test('a sent quotation past its date reads as expired; others keep their status', () {
    expect(quote('CUSTOMER_SENT', past).displayStatus, 'EXPIRED');
    expect(quote('CUSTOMER_SENT', future).displayStatus, 'CUSTOMER_SENT');
    expect(quote('CONVERTED', past).displayStatus, 'CONVERTED',
        reason: 'an answered quotation does not expire',);
  });

  test('timeline: expired instead of "Awaiting customer response", no convert step', () {
    final steps = QuotationWorkflow.stepsFor(quote('CUSTOMER_SENT', past));
    final titles = steps.map((s) => s.title).toList();
    expect(titles, contains('Expired'));
    expect(titles, isNot(contains('Converted to Order')));
    expect(steps.firstWhere((s) => s.title == 'Expired').subtitle, contains('Ask for a new quotation'));

    final live = QuotationWorkflow.stepsFor(quote('CUSTOMER_SENT', future));
    expect(live.map((s) => s.subtitle), contains('Awaiting customer response'));
  });
}
