import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/auth/data/models/capabilities_model.dart';
import 'package:greenroot_mobile/features/notifications/notifications.dart';

AppNotification n(Object? data) => AppNotification.fromJson({
      'id': 1,
      'notification_code': 'NTF-1',
      'notification_type': 'X',
      'notification_status': 'PENDING',
      'created_at': '2026-10-26T00:00:00Z',
      'data': data,
    });

void main() {
  const owner = UserCapabilities(isNurseryOwner: true);
  const driver = UserCapabilities(hasDriverProfile: true);
  const customer = UserCapabilities();

  test('reads the link whether data is a JSON string or an object', () {
    final a = n('{"entity":"order","id":41}');
    expect((a.entity, a.entityId), ('order', 41));
    final b = n({'entity': 'quotation', 'id': 65});
    expect((b.entity, b.entityId), ('quotation', 65));
    for (final none in ['{}', null, 'not json']) {
      expect(n(none).entityId, isNull);
    }
  });

  test('opens the record in the place that fits the person', () {
    expect(notificationRoute(n('{"entity":"quotation","id":65}'), customer), '/quotations/65');
    expect(notificationRoute(n('{"entity":"order","id":41}'), owner), '/orders/41');
    final trip = n('{"entity":"dispatch","id":22}');
    expect(notificationRoute(trip, driver), '/driver/trip/22');
    expect(notificationRoute(trip, owner), '/dispatches/22');
    expect(notificationRoute(trip, customer), '/dispatches/22/buyer-track');
    expect(notificationRoute(n('{"entity":"subscription","id":9}'), owner), '/subscription');
    expect(notificationRoute(n('{}'), owner), isNull);
  });
}
