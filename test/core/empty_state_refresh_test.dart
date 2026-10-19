import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/empty_state.dart';

void main() {
  testWidgets('pulling down an empty list reloads it', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.inbox,
          title: 'No quotations yet',
          onRefresh: () async => reloads++,
        ),
      ),
    ),);

    await tester.fling(find.text('No quotations yet'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(reloads, 1);
  });
}
