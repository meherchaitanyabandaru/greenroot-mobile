import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/qr/sheets/invite_sheet.dart';

import '../helpers/fake_api_client.dart';

// A scanned manager invite must say which nursery, whose and where, and ask
// before joining: a wrong scan must not silently make someone an employee.
void main() {
  testWidgets('scanned invite shows nursery, owner, place; Not now joins nothing',
      (tester) async {
    final fake = FakeApiClient();
    fake.enqueue(response: {
      'invite': {
        'invite_uuid': '5f13fbd5-444e-4bd9-8940-64fd966bc940',
        'invite_type': 'MANAGER_INVITE',
        'nursery_name': 'Suresh Green Nursery',
        'owner_name': 'Suresh Owner',
        'owner_mobile_hint': '0001',
        'nursery_place': 'Rajahmundry, Andhra Pradesh',
        'inviter_name': 'Suresh Owner',
        'status': 'PENDING',
      },
    },);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InviteSheet(
              uuid: '5f13fbd5-444e-4bd9-8940-64fd966bc940',
              onScanAnother: () {},
              onResult: (_) {},
            ),
          ),
        ),
      ),
    ),);
    await tester.pumpAndSettle();

    expect(find.text('Suresh Green Nursery'), findsWidgets);
    expect(find.text('Suresh Owner · mobile ending 0001'), findsOneWidget);
    expect(find.text('Rajahmundry, Andhra Pradesh'), findsOneWidget);

    await tester.tap(find.text('Accept Invite'));
    await tester.pumpAndSettle();
    expect(find.text('Join Suresh Green Nursery as manager?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.where((c) => c.method == 'POST'),
      isEmpty,
      reason: 'declining the confirmation must not accept the invite',
    );
  });
}
