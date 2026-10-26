import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/invites/invite_accept_screen.dart';
import 'package:greenroot_mobile/features/invites/pending_invites_banner.dart';

Future<void> pump(WidgetTester t, List<InviteDetail> invites) async {
  await t.pumpWidget(ProviderScope(
    overrides: [pendingInvitesProvider.overrideWith((ref) async => invites)],
    child: const MaterialApp(home: Scaffold(body: PendingInvitesBanner())),
  ),);
  await t.pump();
}

void main() {
  testWidgets('an invite waiting for this number is offered', (t) async {
    await pump(t, [
      InviteDetail.fromJson({
        'invite_uuid': 'abc',
        'invite_type': 'MANAGER_INVITE',
        'nursery_name': 'Lakshmi Gardens',
        'status': 'PENDING',
      }),
    ]);
    expect(find.text('You have an invite'), findsOneWidget);
    expect(find.text('Lakshmi Gardens invited you · Manager Invite'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('no invites: nothing shown', (t) async {
    await pump(t, const []);
    expect(find.text('You have an invite'), findsNothing);
  });
}
