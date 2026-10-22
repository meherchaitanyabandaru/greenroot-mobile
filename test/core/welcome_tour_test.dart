import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/welcome_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tour shows once per role; Profile can reopen it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      },),
    ),);

    Future<bool> show(TourRole r, {bool force = false}) async {
      final f = showWelcomeTour(ctx, r, force: force);
      await tester.pumpAndSettle();
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
      }
      return f;
    }

    expect(await show(TourRole.driver), isTrue);
    expect(find.text('Join a trip'), findsNothing); // closed again
    expect(await show(TourRole.driver), isFalse, reason: 'only once');
    expect(await show(TourRole.owner), isTrue, reason: 'each role has its own');
    expect(await show(TourRole.driver, force: true), isTrue, reason: 'Profile reopens it');
  });
}
