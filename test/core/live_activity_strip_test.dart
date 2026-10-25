import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/live_activity_strip.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('loading says what is happening', (tester) async {
    await tester.pumpWidget(_host(const LiveActivityStrip(activity: LiveActivity.loading)));
    expect(find.bySemanticsLabel('Loading plants…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600)); // it animates without errors
  });

  testWidgets('stands still when the phone asks for reduced motion', (tester) async {
    await tester.pumpWidget(_host(
      const LiveActivityStrip(activity: LiveActivity.loading),
      reduceMotion: true,
    ),);
    // pumpAndSettle only returns when nothing is animating.
    await tester.pumpAndSettle();
    expect(find.byType(LiveActivityStrip), findsOneWidget);
  });
}
