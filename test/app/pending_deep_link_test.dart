import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/app/pending_deep_link.dart';

void main() {
  test('a deep link is returned once after sign-in', () {
    PendingDeepLink.remember(Uri.parse('/invite/abc-123'));
    expect(PendingDeepLink.take(), '/invite/abc-123');
    expect(PendingDeepLink.take(), isNull);
  });

  test('splash, sign-in and home are not remembered', () {
    for (final path in ['/', '/login', '/otp', '/home']) {
      PendingDeepLink.remember(Uri.parse(path));
      expect(PendingDeepLink.take(), isNull, reason: path);
    }
  });

  test('query parameters are kept', () {
    PendingDeepLink.remember(Uri.parse('/orders/5?tab=items'));
    expect(PendingDeepLink.take(), '/orders/5?tab=items');
  });
}
