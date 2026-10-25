import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/mango/mango_popups.dart';

void main() {
  testWidgets('counts open dialogs and sheets, not pages', (tester) async {
    final observer = MangoPopupObserver();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [observer],
      home: const Scaffold(body: Text('home')),
    ),);
    expect(observer.open.value, 0);

    key.currentState!.push(MaterialPageRoute(builder: (_) => const Text('page')));
    await tester.pumpAndSettle();
    expect(observer.open.value, 0, reason: 'a page is not a popup');

    showDialog<void>(context: key.currentContext!, builder: (_) => const Text('dialog'));
    await tester.pumpAndSettle();
    expect(observer.open.value, 1);

    showModalBottomSheet<void>(context: key.currentContext!, builder: (_) => const Text('sheet'));
    await tester.pumpAndSettle();
    expect(observer.open.value, 2);

    key.currentState!.pop();
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.open.value, 0);
  });
}
