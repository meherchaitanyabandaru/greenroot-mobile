import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/mango/mango_controller.dart';
import 'package:greenroot_mobile/core/mango/mango_finder.dart';
import 'package:greenroot_mobile/core/mango/mango_guides.dart';
import 'package:greenroot_mobile/core/mango/mango_layer.dart';
import 'package:greenroot_mobile/core/theme/app_theme.dart';

const _guide = MangoGuide(
  id: 'test',
  title: 'Test guide',
  audiences: {MangoAudience.owner},
  steps: [
    MangoStep(['Go'], 'Tap Go.'),
    MangoStep.say('All done here.'),
  ],
);

void main() {
  group('guides', () {
    test('ids unique, every guide has steps and an audience', () {
      final ids = mangoGuides.map((g) => g.id).toSet();
      expect(ids.length, mangoGuides.length);
      for (final g in mangoGuides) {
        expect(g.steps, isNotEmpty, reason: g.id);
        expect(g.audiences, isNotEmpty, reason: g.id);
      }
    });

    test('guides respect roles', () {
      final guest = guidesFor(MangoAudience.guest).map((g) => g.id);
      expect(guest, ['signup']);
      final customer = guidesFor(MangoAudience.customer).map((g) => g.id);
      expect(customer, isNot(contains('quotation_seller')));
      expect(customer, contains('order_status_customer'));
      final driver = guidesFor(MangoAudience.driver).map((g) => g.id);
      expect(driver, ['driver_trip']);
      // Required workflows exist for sellers.
      final seller = guidesFor(MangoAudience.owner).map((g) => g.id);
      for (final id in [
        'post_ad',
        'search_nearby',
        'contact_seller',
        'quotation_seller',
        'order_seller',
      ]) {
        expect(seller, contains(id));
      }
    });

    test('guides for the current screen come first', () {
      final ranked =
          rankGuides(MangoAudience.owner, (l) => l == 'Order Timeline');
      expect(ranked.first.guide.id, 'order_seller');
      expect(ranked.first.here, isTrue);
      expect(ranked.skip(1).every((e) => !e.here), isTrue);
    });
  });

  group('controller', () {
    test('next, back, finish, replay, exit', () {
      final c = MangoController()..start(_guide);
      expect(c.isFirst, isTrue);
      c.back(); // nothing before the first step
      expect(c.stepIndex, 0);
      c.next();
      expect(c.isLast, isTrue);
      c.next();
      expect(c.done, isTrue);
      c.back();
      expect(c.done, isFalse);
      c.next();
      c.replay();
      expect((c.stepIndex, c.done), (0, false));
      c.exit();
      expect(c.active, isFalse);
    });
  });

  group('finder', () {
    testWidgets('finds the visible button, not a hidden tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Go')),
                const SizedBox(
                  height: 50,
                  child: IndexedStack(
                    index: 0,
                    children: [Text('Shown'), Text('Hidden tab')],
                  ),
                ),
                const Offstage(child: Text('Offstage label')),
                Row(
                  children: [
                    Checkbox(value: false, onChanged: (_) {}),
                    // Like login: the label is its own tap area inside a Wrap.
                    Expanded(
                      child: Wrap(
                        children: [
                          InkWell(onTap: () {}, child: const Text('I agree')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      final go = MangoFinder.find(['Go']);
      expect(
        go?.widget,
        isA<ElevatedButton>(),
        reason: 'spotlights the button, not just its text',
      );
      expect(MangoFinder.onScreen('Shown'), isTrue);
      expect(MangoFinder.onScreen('Hidden tab'), isFalse);
      expect(MangoFinder.onScreen('Offstage label'), isFalse);
      expect(MangoFinder.onScreen('Nope'), isFalse);
      expect(
        MangoFinder.find(['I agree'])?.widget,
        isA<Row>(),
        reason: 'checkbox label spotlights the checkbox too',
      );
    });
  });

  group('layer', () {
    testWidgets('launch, spotlight, tap-through, finish, replay, exit',
        (tester) async {
      var taps = 0;
      final c = MangoController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light, // real button styles
          builder: (context, child) => MangoLayer(
            controller: c,
            audience: () => MangoAudience.owner,
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      // The Ask Mango button opens the picker.
      await tester.tap(find.text('🥭'));
      await tester.pumpAndSettle();
      expect(
        find.text('Hi! I am Mango. What do you want to do?'),
        findsOneWidget,
      );
      c.start(_guide);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Tap Go.'), findsOneWidget);
      expect(find.text('👆'), findsOneWidget, reason: 'pointing hand shown');

      // The real button is tappable through the spotlight, and the guide moves on.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Go'));
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('All done here.'), findsOneWidget);

      await tester.tap(find.text('Finish'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Nice work'), findsOneWidget);
      await tester.tap(find.text('Replay'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Tap Go.'), findsOneWidget);

      // Android Back closes the guide instead of leaving the page.
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pump();
      expect(c.active, isFalse);
      c.start(_guide);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.active, isFalse);
      expect(find.text('Tap Go.'), findsNothing);
    });
  });
}
