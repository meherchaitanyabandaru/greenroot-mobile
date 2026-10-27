// Main screens on a small phone (360x640) at normal and large text, on real
// API data: any layout overflow fails the test (Flutter reports it as an error).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:greenroot_mobile/features/buyer/buyer_tab.dart';
import 'package:greenroot_mobile/features/dispatches/delivery_confirmation.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';
import 'package:greenroot_mobile/features/notifications/notification_list_screen.dart';
import 'package:greenroot_mobile/features/orders/order_detail_screen.dart';
import 'package:greenroot_mobile/features/owner/owner_tab.dart';
import 'package:greenroot_mobile/features/profile/my_addresses_screen.dart';
import 'package:greenroot_mobile/features/profile/profile_screen.dart';
import 'package:greenroot_mobile/features/quotations/quotation_detail_screen.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_payment_screen.dart';

import 'package:greenroot_mobile/core/theme/app_theme.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fixtures.dart';

const _page = {'page': 1, 'per_page': 20, 'total': 1, 'total_pages': 1};

void main() {
  late FakeApiClient fake;
  setUp(() {
    fake = FakeApiClient()..reset();
    final q = (fixture('quotation_detail') as Map<String, dynamic>)['quotation'];
    final o = (fixture('order_detail') as Map<String, dynamic>)['order'] as Map<String, dynamic>;
    fake
      ..route('/quotations', {'quotations': [q], 'pagination': _page})
      ..route('/quotations/${q['id']}', {'quotation': q})
      ..route('/orders', {'orders': [o], 'pagination': _page})
      ..route('/orders/${o['id']}', {'order': o})
      ..route('/dispatches', fixture('dispatches_buyer_list'))
      ..route('/subscription-plans', fixture('subscription_plans'))
      ..route('/subscriptions/me', fixture('subscriptions_me'))
      ..route('/notifications', fixture('notifications'))
      ..route('/addresses', fixture('addresses'))
      ..route('/nurseries/1', fixture('nursery_detail'));
  });

  final q = (fixture('quotation_detail') as Map<String, dynamic>)['quotation'] as Map<String, dynamic>;
  final o = (fixture('order_detail') as Map<String, dynamic>)['order'] as Map<String, dynamic>;
  final sub = ((fixture('subscriptions_me') as Map)['subscriptions'] as List).first as Map;
  final trip = Dispatch.fromJson((fixture('dispatch_buyer_on_the_way') as Map<String, dynamic>)['dispatch'] as Map<String, dynamic>);

  final screens = <String, (String, Widget)>{
    'login': ('buyer', const LoginScreen()),
    'buying (quotations)': ('buyer', const BuyerTab()),
    'quotation detail': ('owner', QuotationDetailScreen(quotationId: q['id'] as int)),
    'order detail': ('owner', OrderDetailScreen(orderId: o['id'] as int)),
    'payment': ('owner', SubscriptionPaymentScreen(subscriptionId: sub['id'] as int)),
    'selling (owner)': ('owner', const OwnerTab()),
    'profile': ('owner', const ProfileScreen()),
    'addresses': ('buyer', const MyAddressesScreen()),
    'notifications': ('buyer', const NotificationListScreen()),
    'delivery code card': ('buyer', Scaffold(body: SingleChildScrollView(child: CustomerDeliveryCard(dispatch: trip, onChanged: (_) {})))),
  };

  for (final scale in [1.0, 1.3]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits 360x640 at ${(scale * 100).round()}% text', (tester) async {
        tester.view.physicalSize = const Size(360 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(fake.apiClient), signedInAs(entry.value.$1)],
          child: MaterialApp(
            theme: AppTheme.light, // the real theme: its button sizes matter
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: entry.value.$2,
          ),
        ),);
        // Some screens pulse their next action forever: pump frames, don't settle.
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
