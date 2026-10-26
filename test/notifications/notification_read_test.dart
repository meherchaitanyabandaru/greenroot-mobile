// Marking notifications read must keep their link, so a read notification
// still opens its order / quotation / trip (regression, 2026-10-26).
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/notifications/notifications.dart';

import '../helpers/fake_api_client.dart';

Map<String, dynamic> _n(int id, {String? readAt, String data = '{}'}) => {
      'id': id,
      'notification_code': 'NTF-$id',
      'notification_type': 'ORDER_ASSIGNED',
      'notification_status': readAt == null ? 'PENDING' : 'READ',
      'read_at': readAt,
      'created_at': '2026-10-26T00:00:00Z',
      'data': data,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
      'notifications': items,
      'pagination': {'page': 1, 'per_page': 20, 'total': items.length, 'total_pages': 1},
    };

void main() {
  late FakeApiClient fake;
  late NotificationListNotifier notifier;

  setUp(() async {
    fake = FakeApiClient()..reset();
    notifier = NotificationListNotifier(NotificationRepository(fake.apiClient));
    fake.enqueue(
      response: _page([
        _n(1, data: '{"entity":"order","id":41}'),
        _n(2, data: '{"entity":"dispatch","id":22}'),
        _n(3, readAt: '2026-10-25T00:00:00Z', data: '{"entity":"quotation","id":65}'),
      ]),
    );
    await notifier.load();
  });

  (String?, int?) link(int id) {
    final n = notifier.state.paged.items.firstWhere((n) => n.id == id);
    return (n.entity, n.entityId);
  }

  test('mark read keeps the link', () async {
    fake.enqueue(response: {});
    await notifier.markRead(1);
    final n = notifier.state.paged.items.first;
    expect(n.isUnread, isFalse);
    expect(link(1), ('order', 41));
    expect(link(2), ('dispatch', 22), reason: 'others untouched');
  });

  test('mark all read keeps every link and the earlier read time', () async {
    fake.enqueue(response: {});
    await notifier.markAllRead();
    expect(notifier.state.paged.items.every((n) => !n.isUnread), isTrue);
    expect([link(1), link(2), link(3)], [('order', 41), ('dispatch', 22), ('quotation', 65)]);
    expect(notifier.state.paged.items.last.readAt, '2026-10-25T00:00:00Z');
  });
}
