// API contract: real API responses (test/contract/fixtures, captured with
// tool/contract_capture.py) parsed with the app's own models. The app parses
// JSON by hand, so a renamed API field would otherwise show up as a blank on
// screen instead of failing a test.
//
// When the API changes a response on purpose: re-capture, see what fails,
// update the model, and commit both together.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/auth/data/models/user_models.dart';
import 'package:greenroot_mobile/features/auth/data/models/workspace_model.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';
import 'package:greenroot_mobile/features/market/local_market_providers.dart';
import 'package:greenroot_mobile/features/notifications/notifications.dart';
import 'package:greenroot_mobile/features/nurseries/nurseries.dart';
import 'package:greenroot_mobile/features/orders/orders.dart';
import 'package:greenroot_mobile/features/profile/my_addresses_screen.dart';
import 'package:greenroot_mobile/features/quotations/quotations.dart';
import 'package:greenroot_mobile/features/subscriptions/subscription_models.dart';

dynamic fixture(String name) =>
    jsonDecode(File('test/contract/fixtures/$name.json').readAsStringSync());

Map<String, dynamic> obj(dynamic d, String key) =>
    (d as Map<String, dynamic>)[key] as Map<String, dynamic>;

List<Map<String, dynamic>> list(dynamic d, String key) =>
    ((d as Map<String, dynamic>)[key] as List).cast<Map<String, dynamic>>();

void main() {
  group('account', () {
    test('GET /users/me', () {
      final u = UserProfile.fromJson(fixture('users_me') as Map<String, dynamic>);
      expect(u.id, greaterThan(0));
      expect(u.firstName, isNotEmpty);
      expect(u.mobile, hasLength(10));
      expect(u.status, isNotNull);
    });

    test('GET /me/workspaces: the owner gets their nursery', () {
      final raw = fixture('workspaces_owner');
      final items = raw is List ? raw : (raw as Map<String, dynamic>)['workspaces'] as List;
      final ws = items.cast<Map<String, dynamic>>().map(Workspace.fromJson).toList();
      expect(ws.where((w) => w.nurseryId != null), isNotEmpty);
      expect(ws.firstWhere((w) => w.nurseryId != null).nurseryName, isNotEmpty);
    });

    test('GET /users/{id}/addresses: exactly one default', () {
      final a = list(fixture('addresses'), 'addresses').map(UserAddress.fromJson).toList();
      expect(a, isNotEmpty);
      expect(a.where((x) => x.isDefault), hasLength(1));
      expect(a.first.addressLine1, isNotEmpty);
      expect(a.first.city, isNotEmpty);
    });
  });

  group('quotations', () {
    test('list and detail', () {
      final l = list(fixture('quotations_list'), 'quotations').map(Quotation.fromJson);
      expect(l, isNotEmpty);
      final q = Quotation.fromJson(obj(fixture('quotation_detail'), 'quotation'));
      expect(q.quotationCode, startsWith('QUO-'));
      expect(q.status, isNotEmpty);
      expect(q.nurseryName, isNotEmpty);
      expect(q.items, isNotEmpty);
      expect(q.items.first.scientificName, isNotEmpty);
      expect(q.items.first.totalPrice, greaterThan(0));
      expect(q.totalAmount, greaterThan(0));
      expect(q.capabilities, isNotNull, reason: 'screens show actions only from capabilities');
      expect(q.lifecycle, isNotNull);
    });
  });

  group('orders', () {
    test('list and a completed order', () {
      expect(list(fixture('orders_list'), 'orders').map(Order.fromJson), isNotEmpty);
      final o = Order.fromJson(obj(fixture('order_detail'), 'order'));
      expect(o.orderNumber, startsWith('ORD-'));
      expect(o.status, 'COMPLETED');
      expect(o.sellerNurseryId, isNotNull);
      expect(o.items, isNotEmpty);
      expect(o.items.first.scientificName, isNotEmpty);
      expect(o.totalAmount, greaterThan(0));
      expect(o.deliverySnapshot?.addressLine1, isNotEmpty);
    });
  });

  group('dispatches', () {
    test("on the way: the customer gets the code and 'received'", () {
      final d = Dispatch.fromJson(obj(fixture('dispatch_buyer_on_the_way'), 'dispatch'));
      expect(d.dispatchCode, startsWith('DSP-'));
      expect(d.deliveryCode, matches(RegExp(r'^\d{4}$')));
      expect(d.capabilities?.canConfirmReceipt, isTrue);
      expect(d.capabilities?.canMarkDelivered, isFalse, reason: 'the customer never delivers');
      expect(d.sellerNurseryName, isNotEmpty);
      expect(d.destinationAddress, isNotEmpty);
    });

    test('outside lorry fields', () {
      final d = Dispatch.fromJson(obj(fixture('dispatch_buyer_on_the_way'), 'dispatch'));
      expect(d.isOutsideTransport, isTrue);
      expect(d.outsideVehicleNumber, isNotEmpty);
      expect(d.capabilities?.canShareCode, isFalse);
    });

    test('delivered, seller view: how it was confirmed, never the code', () {
      final d = Dispatch.fromJson(obj(fixture('dispatch_seller_delivered'), 'dispatch'));
      expect(d.status, 'DELIVERED');
      expect(d.deliveryConfirmation, isIn(['CUSTOMER_CODE', 'CUSTOMER_APP', 'UNCONFIRMED']));
      expect(d.deliveryCode, isNull);
      expect(d.deliveryDate, isNotNull);
    });

    test('buyer list parses', () {
      expect(list(fixture('dispatches_buyer_list'), 'dispatches').map(Dispatch.fromJson), isNotEmpty);
    });
  });

  group('subscriptions', () {
    test('mine, plans and payments', () {
      final s = list(fixture('subscriptions_me'), 'subscriptions').map(SubscriptionModel.fromJson).first;
      expect(s.planName, isNotEmpty);
      expect(s.status, isNotEmpty);
      expect(s.endDate, isNotNull);
      final plans = list(fixture('subscription_plans'), 'plans').map(SubscriptionPlan.fromJson).toList();
      final growth = plans.firstWhere((p) => p.planCode == 'GROWTH');
      expect(growth.monthlyPrice, 499);
      expect([for (final c in growth.cyclePrices) (c.billingCycle, c.months, c.discountPercent, c.amount)], [
        ('MONTHLY', 1, 0, 499.0),
        ('QUARTERLY', 3, 5, 1422.15),
        ('SIX_MONTH', 6, 10, 2694.6),
        ('YEARLY', 12, 15, 5089.8),
      ], reason: 'the payment screen prices from this',);
      expect(plans.where((p) => p.isPaid).map((p) => p.planCode), containsAll(['BASIC', 'GROWTH', 'ENTERPRISE']));
      expect(plans.firstWhere((p) => p.planCode == 'TRIAL').isPaid, isFalse);
      final pays = list(fixture('subscription_payments'), 'payments').map(SubscriptionPayment.fromJson);
      expect(pays.first.amount, greaterThan(0));
      expect(pays.first.status, isNotEmpty);
    });
  });

  group('market', () {
    test('ads near me: distance and seller', () {
      final ads = list(fixture('market_ads'), 'ads').map(MarketAd.fromJson).toList();
      expect(ads, isNotEmpty);
      expect(ads.first.distanceKm, isNotNull, reason: "the card shows '<1 km'");
      expect(ads.first.nurseryName, isNotEmpty);
      expect(ads.first.plantName, isNotEmpty);
    });

    test('ad detail', () {
      final ad = MarketAd.fromJson(obj(fixture('market_ad_detail'), 'ad'));
      expect(ad.title, isNotEmpty);
      expect(ad.status, isNotEmpty);
      expect(ad.postedByName, isNotEmpty);
    });

    test('received chats', () {
      final e = list(fixture('market_enquiries'), 'enquiries').map(MarketEnquiry.fromJson).toList();
      expect(e, isNotEmpty);
      expect(e.first.adTitle, isNotEmpty);
      expect(e.first.enquiryNurseryName, isNotEmpty);
    });
  });

  test('notifications parse', () {
    final n = list(fixture('notifications'), 'notifications').map(AppNotification.fromJson).toList();
    expect(n, isNotEmpty);
    expect(n.first.title, isNotEmpty);
  });

  test('nursery detail', () {
    final n = Nursery.fromJson(obj(fixture('nursery_detail'), 'nursery'));
    expect(n.name, isNotEmpty);
    expect(n.status, 'APPROVED');
    expect(n.addresses, isNotEmpty);
  });
}
