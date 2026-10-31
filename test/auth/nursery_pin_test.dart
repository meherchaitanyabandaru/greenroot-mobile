// A nursery's PIN code is required: the map (OpenStreetMap) does not know
// every PIN, so the owner types it when it is missing.
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/auth/presentation/screens/nursery_registration_screen.dart';

void main() {
  test('PIN code: required, 6 digits, not starting with 0', () {
    expect(validNurseryPin(''), 'PIN code is required');
    expect(validNurseryPin('  '), 'PIN code is required');
    expect(validNurseryPin('53312'), isNotNull);
    expect(validNurseryPin('033126'), isNotNull);
    expect(validNurseryPin('533126'), isNull);
    expect(validNurseryPin(' 500081 '), isNull);
  });
}
