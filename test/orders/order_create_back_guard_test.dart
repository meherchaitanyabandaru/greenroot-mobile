import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/orders/order_create_screen.dart';

void main() {
  testWidgets('a typed buyer mobile is not dropped silently on Back',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OrderCreateScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number (10 digits)'),
      '9811200004',
    );
    await tester.pump();
    await tester.binding.handlePopRoute(); // system Back
    await tester.pumpAndSettle();

    expect(find.text('Discard this order?'), findsOneWidget);
  });
}
