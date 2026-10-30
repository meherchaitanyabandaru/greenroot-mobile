// Confirmations: every statement must be ticked; the payload carries the
// wording version; a trip that asks for none does not show the sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/consent/consent.dart';

const _tpl = ConsentTemplate(ConsentStep.buyerDelivery, 3, 'Confirming delivery', [
  'I received the plants.',
  'A hidden problem can still be reported.',
]);

void main() {
  testWidgets('Confirm works only with every statement ticked; returns version 3', (tester) async {
    Map<String, dynamic>? got;
    await tester.pumpWidget(ProviderScope(
      overrides: [consentTemplatesProvider.overrideWith((ref) async => {ConsentStep.buyerDelivery: _tpl})],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => got = await askConsent(context, ref, ConsentStep.buyerDelivery, evidence: ['p1']),
            child: const Text('go'),
          ),
        ),
      ),
    ),);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('A hidden problem can still be reported.'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm');
    await tester.tap(find.text('I received the plants.'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'one of two ticked');
    await tester.tap(find.text('A hidden problem can still be reported.'));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(got, {'consent_version': 3, 'accepted': true, 'evidence': ['p1']});
  });

  testWidgets('Back gives nothing (the action does not happen)', (tester) async {
    Map<String, dynamic>? got = {'x': 1};
    await tester.pumpWidget(ProviderScope(
      overrides: [consentTemplatesProvider.overrideWith((ref) async => {ConsentStep.buyerDelivery: _tpl})],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => got = await askConsent(context, ref, ConsentStep.buyerDelivery),
            child: const Text('go'),
          ),
        ),
      ),
    ),);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('wording that cannot load: told why, nothing is confirmed', (tester) async {
    Map<String, dynamic>? got = {'x': 1};
    await tester.pumpWidget(ProviderScope(
      overrides: [consentTemplatesProvider.overrideWith((ref) async => throw Exception('offline'))],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => got = await askConsent(context, ref, ConsentStep.buyerDelivery),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(got, isNull);
    expect(find.textContaining('Could not load what to confirm'), findsOneWidget);
  });
}
