// Swipe to delete with Undo: the row goes at once; the server delete is sent
// only when the Undo window passes, and a failed delete puts the row back.
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
      'title': 'Note $id',
      'notification_status': read ? 'READ' : 'SENT',
      'read_at': read ? '2026-10-26T00:00:00Z' : null,
      'created_at': '2026-10-26T00:00:00Z',
      'data': '{}',
    };

Map<String, dynamic> _page() => {
      'notifications': [_n(3), _n(2, read: true), _n(1)],
      'pagination': {'page': 1, 'per_page': 20, 'total': 3, 'total_pages': 1},
      'unread_count': 2,
    };

List<int> _ids(NotificationListNotifier n) => [for (final x in n.state.paged.items) x.id];
bool _deleted(FakeApiClient f, int id) =>
    f.calls.any((c) => c.method == 'DELETE' && c.path.endsWith('/notifications/$id'));

void main() {
  late FakeApiClient fake;
  late NotificationListNotifier notifier;

  setUp(() async {
    fake = FakeApiClient()..reset();
    notifier = NotificationListNotifier(NotificationRepository(fake.apiClient));
    fake.enqueue(response: _page());
    await notifier.load();
  });

  test('hide takes it out and off the count; restore puts it back in place', () {
    final (n, index) = notifier.hide(3)!;
    expect(_ids(notifier), [2, 1]);
    expect(notifier.state.unreadCount, 1);
    notifier.restore(n, index);
    expect(_ids(notifier), [3, 2, 1]);
    expect(notifier.state.unreadCount, 2);
    notifier.restore(n, index); // twice is harmless
    expect(_ids(notifier), [3, 2, 1]);
    expect(notifier.hide(99), isNull);
  });

  test('hiding a read one leaves the count alone', () {
    notifier.hide(2);
    expect(notifier.state.unreadCount, 2);
  });

  test('a failed server delete puts it back', () async {
    final (n, index) = notifier.hide(1)!;
    fake.enqueue(type: FakeResponseType.serverError);
    expect(await notifier.commitDelete(n, index), isFalse);
    expect(_ids(notifier), [3, 2, 1]);
    expect(notifier.state.unreadCount, 2);
  });

  Future<void> open(WidgetTester tester) async {
    fake.enqueue(response: _page()); // the screen reloads on open
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationListProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: NotificationListScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> swipe(WidgetTester tester, String title) async {
    await tester.drag(find.text(title), const Offset(-600, 0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('swipe then Undo: back again, nothing deleted', (tester) async {
    await open(tester);
    await swipe(tester, 'Note 3');
    expect(find.text('Note 3'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Note 3'), findsOneWidget);
    expect(_deleted(fake, 3), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swipe and let the Undo window pass: deleted on the server', (tester) async {
    await open(tester);
    await swipe(tester, 'Note 3');
    fake.enqueue(response: {});
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // past the 4 s window
    }
    expect(_deleted(fake, 3), isTrue);
    expect(find.text('Note 3'), findsNothing);
    expect(notifier.state.unreadCount, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
