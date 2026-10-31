import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/action_tile_grid.dart';

void main() {
  testWidgets(
      'long labels wrap on a narrow phone with large font, tiles in a row match',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget tile(String label) => Container(
          key: ValueKey(label),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.add),
            Expanded(child: Text(label, maxLines: 2)),
          ],),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 640), textScaler: TextScaler.linear(1.5),),
          child: Scaffold(
            body: ActionTileGrid(children: [
              tile('New Order'),
              tile('New Quotation'),
              tile('Create Plant Ad'),
            ],),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('New Order'))).height,
      tester.getSize(find.byKey(const ValueKey('New Quotation'))).height,
    );
    expect(find.text('Create Plant Ad'), findsOneWidget);
  });
}
