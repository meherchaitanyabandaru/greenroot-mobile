// Screen-level checks for today's fixes: what the user sees and what the
// app sends. Fast (no device), run in CI.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/qr/scanner_support.dart';
import 'package:greenroot_mobile/features/owner/customer_picker_sheet.dart';
import 'package:greenroot_mobile/features/plants/plant_picker.dart';
import 'package:greenroot_mobile/features/profile/my_addresses_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../helpers/fake_api_client.dart';

Widget _app(FakeApiClient fake, Widget body) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp(home: Scaffold(body: body)),
    );

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  testWidgets('customer picker: search by name or part of the mobile', (tester) async {
    fake.route('/customers', {
      'customers': [
        {'user_id': 1, 'first_name': 'Kiran', 'last_name': 'Kumar', 'mobile': '9811100004'},
        {'user_id': 2, 'first_name': 'Ravi', 'mobile': '9300000000'},
        {'user_id': 3, 'first_name': 'Sita', 'mobile': '9400000001'},
      ],
    });
    await tester.pumpWidget(_app(fake, const CustomerPickerSheet(nurseryId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('3 customers · newest first'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kir');
    await tester.pump();
    expect(find.text('Kiran Kumar'), findsOneWidget);
    expect(find.text('Ravi'), findsNothing);
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0001');
    await tester.pump();
    expect(find.text('Sita'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No customer matches "zzz"'), findsOneWidget);
  });

  testWidgets('scanner error: plain words, a retry and the support code', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: ScannerErrorView(
        error: const MobileScannerException(errorCode: MobileScannerErrorCode.permissionDenied),
        onRetry: () => retried++,
      ),
    ),);
    expect(find.text('Camera permission is off'), findsOneWidget);
    expect(find.textContaining('Settings'), findsOneWidget);
    expect(find.text('Code: permissionDenied'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);

    await tester.pumpWidget(const MaterialApp(
      home: ScannerErrorView(
        error: MobileScannerException(errorCode: MobileScannerErrorCode.genericError),
        onRetry: _noop,
      ),
    ),);
    expect(find.text("The camera didn't start"), findsOneWidget);
  });

  testWidgets('address form: the default stays until another is chosen', (tester) async {
    Future<void> save(AddressFormData _) async {}
    const address = UserAddress(id: 1, addressLine1: 'Plot 12', city: 'Hyderabad', isDefault: true);
    await tester.pumpWidget(_app(fake, AddressFormScreen(existing: address, onSave: save)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Set as default address'), 200,
        scrollable: find.byType(Scrollable).first,);
    expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull);
    expect(find.text('To change it, set another address as default.'), findsOneWidget);

    const other = UserAddress(id: 2, addressLine1: 'Godown 2', city: 'Hyderabad', isDefault: false);
    await tester.pumpWidget(_app(fake, AddressFormScreen(existing: other, onSave: save)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Set as default address'), 200,
        scrollable: find.byType(Scrollable).first,);
    expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNotNull);
  });

  testWidgets('plant not found: suggest it to GreenRoot', (tester) async {
    fake.route('/plants/suggestions', {'result': 'SUBMITTED'});
    await tester.pumpWidget(_app(fake, const PlantNotFound(query: 'Kanakambaram')));
    expect(find.text('No plants found for "Kanakambaram"'), findsOneWidget);

    await tester.tap(find.text('Suggest "Kanakambaram" to GreenRoot'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Notes (optional)'), 'Orange flower');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final call = fake.calls.singleWhere((c) => c.path.endsWith('/plants/suggestions'));
    expect(call.method, 'POST');
    expect(call.data['name'], 'Kanakambaram');
    expect(call.data['notes'], 'Orange flower');
    expect(find.text('Thanks! We\'ll review "Kanakambaram" and let you know.'), findsOneWidget);
  });
}

void _noop() {}
