// Stars are labelled buttons, so screen-reader users can rate too.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/ratings/rating_screen.dart';

import '../helpers/fake_api_client.dart';

void main() {
  testWidgets('each star is a labelled button that selects on tap', (tester) async {
    final fake = FakeApiClient()..reset();
    fake.route('/ratings/trip/7', {'rating': null});
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fake.apiClient)],
      child: const MaterialApp(home: TripRatingScreen(dispatchId: 7)),
    ),);
    await tester.pumpAndSettle();

    final fourth = find.bySemanticsLabel('4 of 5 stars');
    expect(fourth, findsWidgets);
    await tester.tap(fourth.first);
    await tester.pump();
    expect(
      tester.getSemantics(fourth.first),
      matchesSemantics(
        label: '4 of 5 stars',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
