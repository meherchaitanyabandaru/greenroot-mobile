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
  testWidgets('loading and in-transit say what is happening', (tester) async {
    await tester.pumpWidget(_host(const LiveActivityStrip(activity: LiveActivity.loading)));
    expect(find.bySemanticsLabel('Loading plants…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600)); // it animates without errors

    await tester.pumpWidget(_host(const LiveActivityStrip(
      activity: LiveActivity.inTransit,
      label: 'Your plants are on the way',
    ),),);
    expect(find.bySemanticsLabel('Your plants are on the way'), findsOneWidget);
  });

  testWidgets('stands still when the phone asks for reduced motion', (tester) async {
    await tester.pumpWidget(_host(
      const LiveActivityStrip(activity: LiveActivity.inTransit),
      reduceMotion: true,
    ),);
    // pumpAndSettle only returns when nothing is animating.
    await tester.pumpAndSettle();
    expect(find.byType(LiveActivityStrip), findsOneWidget);
  });
}
