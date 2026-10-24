// A retry after a lost response must reuse the form's Idempotency-Key, so the
// API returns the first order instead of creating a duplicate.
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';
import 'package:greenroot_mobile/features/quotations/quotations.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  test('keys are 32 random hex characters', () {
    final a = newIdempotencyKey(), b = newIdempotencyKey();
    expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(a, isNot(b));
  });

  test('order: the retry after a network failure sends the same key', () async {
    final repo = OrderRepository(fake.apiClient);
    final key = newIdempotencyKey();
    final order = (fixture('order_detail') as Map<String, dynamic>)['order'];
    Future<Order> submit() => repo.createOrder(
          buyerMobile: '7010000002',
          sellerNurseryId: 1,
          items: const [],
          idempotencyKey: key,
        );

    fake.setError(FakeResponseType.networkError);
    await expectLater(submit(), throwsA(isA<AppError>()));
    fake.setResponse({'order': order});
    await submit();

    final keys = fake.calls.map((c) => c.headers['Idempotency-Key']).toList();
    expect(keys, [key, key]);
  });

  test('quotation: create sends the key; other calls send none', () async {
    final repo = QuotationRepository(fake.apiClient);
    final q = (fixture('quotation_detail') as Map<String, dynamic>)['quotation'];
    fake.setResponse({'quotation': q});
    await repo.createQuotation(quotationType: 'INTERNAL', nurseryId: 1, items: const [], idempotencyKey: 'k-1234567890');
    expect(fake.calls.single.headers['Idempotency-Key'], 'k-1234567890');

    fake
      ..reset()
      ..setResponse({'quotation': q});
    await repo.acceptQuotation(5);
    expect(fake.calls.single.headers.containsKey('Idempotency-Key'), isFalse);
  });
}
