import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/utilities/indian_mobile.dart';

void main() {
  test('normalizes the prefixes the API accepts', () {
    for (final raw in ['9876543210', '+91 98765 43210', '919876543210', '09876543210', '98765-43210']) {
      expect(normalizeIndianMobile(raw), '9876543210', reason: raw);
    }
  });

  test('validator matches the API rule', () {
    expect(validateIndianMobile('9876543210'), isNull);
    expect(validateIndianMobile('6000000001'), isNull);
    for (final bad in ['5876543210', '0000000000', '12345', '98765432101']) {
      expect(validateIndianMobile(bad), isNotNull, reason: bad);
    }
    expect(validateIndianMobile(''), isNotNull);
    expect(validateIndianMobile('', required: false), isNull);
  });

  test('pasting a formatted number keeps the real 10 digits', () {
    final out = IndianMobileInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '+91 98765 43210'),
    );
    expect(out.text, '9876543210');
  });
}
