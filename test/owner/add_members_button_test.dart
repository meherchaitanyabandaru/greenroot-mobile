import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:greenroot_mobile/features/owner/add_members_button.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

// An empty picker sheet with the button; records where it navigates.
Future<List<String>> _tap(
    WidgetTester tester, String who, Widget button,) async {
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
                context: context, builder: (_) => Center(child: button),),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
          path: '/nursery/members',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Text('members');
          },),
      GoRoute(
          path: '/connections',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Text('connections');
          },),
    ],
  );
  await tester.pumpWidget(ProviderScope(
      overrides: [signedInAs(who)],
      child: MaterialApp.router(routerConfig: router),),);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  final add = find.byType(TextButton).last;
  if (find.textContaining('Add ').evaluate().isEmpty) return pushed;
  await tester.tap(add);
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  setUp(() => FakeApiClient().reset());

  testWidgets(
      'owner: Add managers opens the managers tab, Add customers the customers tab',
      (tester) async {
    final m = await _tap(tester, 'owner', const AddMembersButton.managers());
    expect(m.single, contains('tab=0'));
    expect(find.text('members'), findsOneWidget);
    final c = await _tap(tester, 'owner', const AddMembersButton.customers());
    expect(c.single, contains('tab=2'));
  });

  testWidgets('manager: no Add managers; Add customers goes to Connections',
      (tester) async {
    expect(await _tap(tester, 'manager', const AddMembersButton.managers()),
        isEmpty,);
    expect(find.text('Add managers'), findsNothing);
    expect(await _tap(tester, 'manager', const AddMembersButton.customers()),
        ['/connections'],);
  });

  testWidgets('customer: no button at all', (tester) async {
    expect(await _tap(tester, 'buyer', const AddMembersButton.customers()),
        isEmpty,);
    expect(find.textContaining('Add '), findsNothing);
  });
}
