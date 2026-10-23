import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/invites/join_confirm.dart';

void main() {
  const manager = InviteFacts(
    inviteType: 'MANAGER_INVITE',
    nurseryName: 'Suresh Green Nursery',
    ownerName: 'Suresh Owner',
    ownerMobileHint: '0001',
    place: 'Rajahmundry, Andhra Pradesh',
    inviterName: 'Suresh Owner',
  );

  test('facts read from the API invite', () {
    final f = InviteFacts.fromJson(const {
      'invite_type': 'MANAGER_INVITE',
      'nursery_name': 'Suresh Green Nursery',
      'owner_name': 'Suresh Owner',
      'owner_mobile_hint': '0001',
      'nursery_place': 'Rajahmundry, Andhra Pradesh',
      'inviter_name': 'Gumastha Manager',
    });
    expect(f.ownerLine, 'Suresh Owner · mobile ending 0001');
    expect(f.place, 'Rajahmundry, Andhra Pradesh');
    expect(f.otherInviter, 'Gumastha Manager', reason: 'a manager sent it, not the owner');
    expect(manager.otherInviter, isNull, reason: 'no repeat when the owner sent it');
  });

  test('working invites need a yes; customer invites do not', () {
    expect(manager.needsConfirm, isTrue);
    expect(const InviteFacts(inviteType: 'DRIVER_INVITE').needsConfirm, isTrue);
    expect(const InviteFacts(inviteType: 'CUSTOMER_INVITE').needsConfirm, isFalse);
  });

  testWidgets('confirm names the nursery, owner and place; "Not now" refuses',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmJoinNursery(context, manager),
          child: const Text('go'),
        ),
      ),
    ),);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Join Suresh Green Nursery as manager?'), findsOneWidget);
    expect(find.text('Suresh Owner · mobile ending 0001'), findsOneWidget);
    expect(find.text('Rajahmundry, Andhra Pradesh'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, join'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
