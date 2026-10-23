import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/unsaved_changes_guard.dart';

void main() {
  Future<void> open(WidgetTester tester, {required bool changed}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => UnsavedChangesGuard(
              hasChanges: changed,
              what: 'quotation',
              child: const Scaffold(body: Text('form')),
            ),
          ),),
          child: const Text('open'),
        ),
      ),
    ),);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute(); // system Back
    await tester.pumpAndSettle();
  }

  testWidgets('Back on a started form asks; Keep editing stays, Discard leaves', (tester) async {
    await open(tester, changed: true);
    await back(tester);
    expect(find.text('Discard this quotation?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('form'), findsOneWidget);

    await back(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('form'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an untouched form closes at once', (tester) async {
    await open(tester, changed: false);
    await back(tester);
    expect(find.text('Discard this quotation?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
