import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/owner/customer_picker_sheet.dart';
import 'package:greenroot_mobile/features/owner/owner_members_screen.dart';

void main() {
  const kiran = NurseryCustomer(
    userId: 1,
    firstName: 'Kiran',
    lastName: 'Kumar',
    mobile: '9811100004',
    email: 'kiran@farm.in',
  );

  test('matches name, email or part of the mobile', () {
    expect(customerMatches(kiran, ''), isTrue);
    expect(customerMatches(kiran, ' KIRAN '), isTrue);
    expect(customerMatches(kiran, 'kumar'), isTrue);
    expect(customerMatches(kiran, '@farm'), isTrue);
    expect(customerMatches(kiran, '0004'), isTrue);
    expect(customerMatches(kiran, '98111 00004'), isTrue); // spaces typed
    expect(customerMatches(kiran, 'ravi'), isFalse);
    expect(customerMatches(kiran, '7777'), isFalse);
  });
}
