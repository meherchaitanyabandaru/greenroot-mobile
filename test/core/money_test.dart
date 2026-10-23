import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/utilities/money.dart';

void main() {
  test('rupees use Indian grouping', () {
    expect(inr(100120), '₹1,00,120.00');
    expect(inr(4500), '₹4,500.00');
    expect(inr(95.5), '₹95.50');
    expect(inr(4500, paise: false), '₹4,500');
  });
}
