// The bell badge and "Mark all read" follow the API's unread_count (the whole
// inbox), not just the page loaded: with 200 notifications, 50 unread and the
// newest 20 all read, the badge still says 50.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/notifications/notification_list_screen.dart';
import 'package:greenroot_mobile/features/notifications/notifications.dart';

import '../helpers/fake_api_client.dart';

Map<String, dynamic> _n(int id, {bool read = false}) => {
      'id': id,
      'notification_code': 'NTF-$id',
      'notification_type': 'SYSTEM',
      'notification_status': read ? 'READ' : 'SENT',
      'read_at': read ? '2026-10-26T00:00:00Z' : null,
      'created_at': '2026-10-26T00:00:00Z',
      'data': '{}',
    };

// Page 1 of 200 (newest first): all 20 read; 50 older ones are unread.
Map<String, dynamic> _newestAllRead({int? unread = 50}) => {
      'notifications': [for (var i = 200; i > 180; i--) _n(i, read: true)],
      'pagination': {'page': 1, 'per_page': 20, 'total': 200, 'total_pages': 10},
      if (unread != null) 'unread_count': unread,
    };

void main() {
  late FakeApiClient fake;
  late NotificationListNotifier notifier;

  setUp(() async {
    fake = FakeApiClient()..reset();
    notifier = NotificationListNotifier(NotificationRepository(fake.apiClient));
    fake.enqueue(response: _newestAllRead());
    await notifier.load();
  });

  test('badge is the server total even when the newest 20 are read', () {
    expect(notifier.state.paged.items.any((n) => n.isUnread), isFalse);
    expect(notifier.state.unreadCount, 50);
  });

  test('reading a read one changes nothing; reading or deleting an unread one takes one off', () async {
    fake.enqueue(response: {});
    await notifier.markRead(200); // already read
    expect(notifier.state.unreadCount, 50);

    fake.enqueue(
      response: {
        'notifications': [_n(150), _n(149)],
        'pagination': {'page': 2, 'per_page': 20, 'total': 200, 'total_pages': 10},
        'unread_count': 50,
      },
    );
    await notifier.loadMore();
    fake.enqueue(response: {});
    await notifier.markRead(150);
    expect(notifier.state.unreadCount, 49);
    fake.enqueue(response: {});
    await notifier.deleteNotification(149);
    expect(notifier.state.unreadCount, 48);
    fake.enqueue(response: {});
    await notifier.markAllRead();
    expect(notifier.state.unreadCount, 0);
  });

  test('an older API without unread_count falls back to the loaded page', () async {
    fake.enqueue(response: _newestAllRead(unread: null));
    await notifier.load();
    expect(notifier.state.unreadCount, 0);
  });

  testWidgets('Mark all read is offered while older unread ones exist', (tester) async {
    fake.enqueue(response: _newestAllRead()); // the screen reloads on open
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationListProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: NotificationListScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // let the reload finish
    }
    expect(notifier.state.paged.items.any((n) => n.isUnread), isFalse);
    expect(find.text('Mark all read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dispose the screen and its timers
  });
}
