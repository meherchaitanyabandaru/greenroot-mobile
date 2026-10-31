// The 🥭 button opens Mango AI; the app shows it only to signed-in owners,
// managers, customers and drivers (app.dart _showMango; the API checks too).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/mango/mango_layer.dart';
import 'package:greenroot_mobile/core/mango/mango_popups.dart';

void main() {
  Future<int Function()> pump(WidgetTester tester, {required bool visible}) async {
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [mangoPopups],
      builder: (context, child) => MangoLayer(visible: () => visible, onAsk: () => asked++, refresh: mangoPopups.open, child: child!),
      home: Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(
        onPressed: () => showDialog<void>(context: ctx, builder: (_) => const AlertDialog(content: Text('a dialog'))),
        child: const Text('open dialog'),
      ),),),),
    ),);
    await tester.pumpAndSettle();
    return () => asked;
  }

  testWidgets('tapping 🥭 opens Mango AI', (tester) async {
    final asked = await pump(tester, visible: true);
    expect(find.bySemanticsLabel('Ask Mango AI'), findsOneWidget);
    await tester.tap(find.text('🥭'));
    expect(asked(), 1);
  });

  testWidgets('hidden where Mango AI is not offered (admins, signing up)', (tester) async {
    await pump(tester, visible: false);
    expect(find.text('🥭'), findsNothing);
  });

  testWidgets('steps aside while a dialog is open', (tester) async {
    await pump(tester, visible: true);
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('🥭'), findsNothing);
    Navigator.of(tester.element(find.text('a dialog'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('🥭'), findsOneWidget);
  });

  test('the old offline guides are gone', () {
    for (final f in ['mango_guides.dart', 'mango_controller.dart', 'mango_finder.dart']) {
      expect(!_exists('lib/core/mango/$f'), isTrue, reason: f);
    }
  });
}

bool _exists(String path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
