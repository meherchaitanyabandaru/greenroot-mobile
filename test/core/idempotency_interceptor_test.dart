import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/idempotency_interceptor.dart';

class _Capture extends RequestInterceptorHandler {
  RequestOptions? passed;
  @override
  void next(RequestOptions requestOptions) => passed = requestOptions;
}

String? keyOf(IdempotencyInterceptor i, String method, String path, Object? data, {Map<String, dynamic>? headers}) {
  final h = _Capture();
  i.onRequest(RequestOptions(method: method, path: path, data: data, headers: headers), h);
  return h.passed!.headers[IdempotencyInterceptor.header] as String?;
}

void main() {
  final t0 = DateTime.utc(2026, 10, 24, 10, 1);
  final ad = {'plant_name': 'Ficus', 'quantity': 50};

  test('the same create resent within the window carries the same key', () {
    var now = t0;
    final i = IdempotencyInterceptor(now: () => now);
    final first = keyOf(i, 'POST', '/api/v1/market/ads', ad);
    now = t0.add(const Duration(minutes: 2));
    expect(keyOf(i, 'POST', '/api/v1/market/ads', ad), first);
    expect(first, hasLength(32), reason: 'the API takes 8-64 characters');
  });

  test('a different create, or the same one much later, is a new request', () {
    var now = t0;
    final i = IdempotencyInterceptor(now: () => now);
    final first = keyOf(i, 'POST', '/api/v1/market/ads', ad);
    expect(keyOf(i, 'POST', '/api/v1/market/ads', {...ad, 'quantity': 51}), isNot(first));
    expect(keyOf(i, 'POST', '/api/v1/orders/7/items', ad), isNot(first));
    now = t0.add(const Duration(hours: 1));
    expect(keyOf(i, 'POST', '/api/v1/market/ads', ad), isNot(first));
  });

  test('only POST creates get a key; explicit keys and chat replies are left alone', () {
    final i = IdempotencyInterceptor(now: () => t0);
    expect(keyOf(i, 'GET', '/api/v1/market/ads', null), isNull);
    expect(keyOf(i, 'POST', '/api/v1/market/enquiries/3/reply', {'body': 'ok'}), isNull);
    expect(keyOf(i, 'POST', '/api/v1/auth/verify-otp', {'otp': '1'}), isNull);
    expect(keyOf(i, 'POST', '/api/v1/orders', {}, headers: {'Idempotency-Key': 'form-key-123'}), 'form-key-123');
    for (final p in ['/api/v1/dispatches', '/api/v1/invites', '/api/v1/vehicles', '/api/v1/top-items',
      '/api/v1/market/ads/9/enquiries', '/api/v1/market/enquiries/9/offers', '/api/v1/payments/manual',
      '/api/v1/users/5/addresses', '/api/v1/plants/suggestions', '/api/v1/drivers/apply',]) {
      expect(keyOf(i, 'POST', p, {'x': 1}), isNotNull, reason: p);
    }
  });

  test('uploads (multipart) are not keyed', () {
    final i = IdempotencyInterceptor(now: () => t0);
    expect(keyOf(i, 'POST', '/api/v1/market/ads', FormData()), isNull);
  });
}
