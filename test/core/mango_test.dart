import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/mango/mango_controller.dart';
import 'package:greenroot_mobile/core/mango/mango_finder.dart';
import 'package:greenroot_mobile/core/mango/mango_guides.dart';
import 'package:greenroot_mobile/core/mango/mango_layer.dart';
import 'package:greenroot_mobile/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // An instruction-only step leaves the app usable (e.g. "open any ad").
      await tester.tap(find.widgetWithText(ElevatedButton, 'Go'));
      expect(taps, 2);

      await tester.tap(find.text('Finish'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Nice work'), findsOneWidget);
      await tester.tap(find.text('Replay'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Tap Go.'), findsOneWidget);

      // Android Back closes the picker; during a guide it is left to the app.
      c.openPicker();
      await tester.pump();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      expect(c.active, isFalse);
      c.start(_guide);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.active, isFalse);
      expect(find.text('Tap Go.'), findsNothing);
    });

    testWidgets(
        'the 🥭 tab can be dragged; it snaps to a side and is remembered',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      Widget app() => MaterialApp(
            builder: (context, child) => MangoLayer(
              controller: MangoController(),
              audience: () => MangoAudience.owner,
              child: child!,
            ),
            home: const Scaffold(body: SizedBox()),
          );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('🥭')).dx,
        lessThan(100),
        reason: 'starts on the left',
      );

      // Drag most of the way right and up, let go mid-screen: it snaps right.
      await tester.drag(find.text('🥭'), const Offset(500, -150));
      await tester.pumpAndSettle();
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getTopRight(find.text('🥭')).dx, greaterThan(width - 48));
      final saved =
          (await SharedPreferences.getInstance()).getString('mango_button_pos');
      expect(saved, startsWith('R:'));

      // A fresh start puts it back where the user left it.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.getTopRight(find.text('🥭')).dx, greaterThan(width - 48));
    });
  });

  testWidgets('the picker offers Ask Mango AI to owners, managers and customers only, and it closes the picker', (tester) async {
    for (final who in [MangoAudience.owner, MangoAudience.manager, MangoAudience.customer, MangoAudience.driver, MangoAudience.guest]) {
      var asked = 0;
      final c = MangoController();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MangoLayer(controller: c, audience: () => who, onAsk: () => asked++, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),);
      await tester.tap(find.text('🥭'));
      await tester.pumpAndSettle();
      final tile = find.text('Ask Mango (voice or text)');
      if (who == MangoAudience.guest || who == MangoAudience.driver) {
        expect(tile, findsNothing, reason: 'Mango AI is for owners, managers and customers');
        continue;
      }
      expect(tile, findsOneWidget, reason: '$who');
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(c.picking, isFalse);
    }
  });
}
