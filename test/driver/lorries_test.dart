// A driver's lorries: choosing the lorry for a trip from its QR, adding a
// lorry (owner without the app), and the owner rules.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/drivers/trip_preview_screen.dart';
import 'package:greenroot_mobile/features/vehicles/my_lorries_screen.dart';
import 'package:greenroot_mobile/features/vehicles/vehicles.dart';

import '../helpers/fake_api_client.dart';

const _code = 'TRIP-0f8fad5b-d9cb-469f-a165-70867728950e';

Map<String, dynamic> _trip(List<Map<String, dynamic>> lorries) => {
      'dispatch': {
        'id': 10,
        'dispatch_code': 'DSP-1',
        'trip_uuid': '0f8fad5b-d9cb-469f-a165-70867728950e',
        'order_id': 5,
        'dispatch_status': 'PENDING',
        'created_at': '2026-10-30T10:00:00Z',
        'driver_vehicles': lorries,
      },
    };

Map<String, dynamic> _lorry(int id, String number, {String? blocked}) => {
      'vehicle_id': id,
      'vehicle_number': number,
      'vehicle_type': 'TRUCK',
      'is_eligible': blocked == null,
      if (blocked != null) 'blocked_reason': blocked,
    };

Widget _preview(FakeApiClient fake) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/p', routes: [
          GoRoute(path: '/p', builder: (_, __) => const TripPreviewScreen(code: _code)),
          GoRoute(path: '/home', builder: (_, __) => const Text('home')),
          GoRoute(path: '/driver/trip/:id', builder: (_, __) => const Text('trip')),
          GoRoute(path: '/driver/lorries', builder: (_, __) => const Text('lorries')),
        ],),
      ),
    );

Finder _acceptButton() => find.byWidgetPredicate(
    (w) => w is ElevatedButton && w.child is! SizedBox,
    description: 'accept button',);

void main() {
  late FakeApiClient fake;
  setUp(() => fake = FakeApiClient()..reset());

  testWidgets('trip QR: only lorries that can take it are offered; the chosen one is sent', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    fake.route('/dispatches/code/${_code.toUpperCase()}', _trip([
      _lorry(1, 'TS09AA1111'),
      _lorry(2, 'TS09BB2222'),
      _lorry(3, 'TS09CC3333', blocked: 'VEHICLE_MAINTENANCE'),
    ]),);
    await tester.pumpWidget(_preview(fake));
    await tester.pumpAndSettle();

    expect(find.text('Which lorry are you taking?'), findsOneWidget);
    expect(find.text('TS09AA1111'), findsOneWidget);
    expect(find.text('TS09BB2222'), findsOneWidget);
    expect(find.text('TS09CC3333'), findsNothing, reason: 'a lorry in maintenance is not offered');
    expect(find.text('Choose your lorry'), findsOneWidget);
    final accept = tester.widget<ElevatedButton>(_acceptButton());
    expect(accept.onPressed, isNull, reason: 'two lorries: the driver must choose');

    await tester.tap(find.text('TS09BB2222'));
    await tester.pump();
    expect(find.text('Accept Trip'), findsOneWidget);

    fake.route('/dispatches', {'dispatches': [], 'pagination': {'page': 1, 'per_page': 50, 'total': 0, 'total_pages': 1}});
    fake.route('/dispatches/10/accept', _trip([])..['dispatch']['dispatch_status'] = 'ACCEPTED');
    await tester.tap(find.text('Accept Trip'));
    await tester.pumpAndSettle();
    final sent = fake.calls.where((c) => c.path.endsWith('/accept')).single.data as Map;
    expect(sent['vehicle_id'], 2);
    expect(sent['trip_code'], _code);
  });

  testWidgets('trip QR: one eligible lorry is chosen for the driver', (tester) async {
    fake.route('/dispatches/code/${_code.toUpperCase()}', _trip([
      _lorry(1, 'TS09AA1111'),
      _lorry(2, 'TS09BB2222', blocked: 'LINK_PENDING'),
    ]),);
    await tester.pumpWidget(_preview(fake));
    await tester.pumpAndSettle();
    expect(find.text('Your lorry'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(_acceptButton()).onPressed, isNotNull);
  });

  testWidgets('trip QR: no lorry can take it — each says why, accept is off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    fake.route('/dispatches/code/${_code.toUpperCase()}', _trip([
      _lorry(1, 'TS09AA1111', blocked: 'LICENCE_EXPIRED'),
      _lorry(2, 'TS09BB2222', blocked: 'VEHICLE_ON_TRIP'),
    ]),);
    await tester.pumpWidget(_preview(fake));
    await tester.pumpAndSettle();
    expect(find.text('None of your lorries can take this trip:'), findsOneWidget);
    expect(find.text(lorryBlockedText('LICENCE_EXPIRED')), findsOneWidget);
    expect(find.text(lorryBlockedText('VEHICLE_ON_TRIP')), findsOneWidget);
    expect(tester.widget<ElevatedButton>(_acceptButton()).onPressed, isNull);
    final myLorries = find.widgetWithText(OutlinedButton, 'My lorries');
    // Below the fold in the test view; what matters is where it leads.
    tester.widget<OutlinedButton>(myLorries).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('lorries'), findsOneWidget);
  });

  testWidgets('add a lorry owned by someone without the app', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: const MaterialApp(home: Scaffold(body: AddLorrySheet())),
    ),);
    // Fields in order: lorry number, capacity, then the owner's name and mobile.
    await tester.enterText(find.byType(TextField).at(0), 'ka01ab1234');
    await tester.tap(find.text('Van'));
    await tester.tap(find.text('Someone else'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add lorry'));
    await tester.pump();
    expect(find.text("Enter the owner's name"), findsOneWidget);
    expect(fake.calls, isEmpty, reason: 'nothing is sent without the owner');

    await tester.enterText(find.byType(TextField).at(2), 'Ramesh');
    await tester.pump();
    expect(find.text("Enter the owner's name"), findsNothing, reason: 'the error clears while typing');
    fake.route('/drivers/me/vehicles', {'vehicle': _lorry(9, 'KA01AB1234', blocked: 'LINK_PENDING')});
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add lorry'));
    await tester.pumpAndSettle();
    final body = fake.calls.single.data as Map;
    expect(body['vehicle_number'], 'KA01AB1234');
    expect(body['vehicle_type'], 'VAN');
    expect(body['is_owner'], false);
    expect(body['owner_name'], 'Ramesh');
    expect(body.containsKey('owner_mobile'), isFalse, reason: 'the owner mobile is optional');
  });

  test('owner rules: me needs nothing; someone else needs a name, mobile optional but whole', () {
    expect(LorryOwnerFields.valid(true, '', ''), isTrue);
    expect(LorryOwnerFields.valid(false, '', ''), isFalse);
    expect(LorryOwnerFields.valid(false, 'Ramesh', ''), isTrue);
    expect(LorryOwnerFields.valid(false, 'Ramesh', '98765'), isFalse);
    expect(LorryOwnerFields.valid(false, 'Ramesh', '+91 98765 43210'), isTrue);
    expect(const LorryOwner.me().toJson(), {'is_owner': true});
    expect(const LorryOwner.other(' Ramesh ', ' 9876543210 ').toJson(),
        {'is_owner': false, 'owner_name': 'Ramesh', 'owner_mobile': '9876543210'},);
  });
}
