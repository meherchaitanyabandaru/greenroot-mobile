// "Clear read notifications": asks first, then deletes only read ones on the
// server (DELETE /notifications/read) and reloads the list.
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

Map<String, dynamic> _page(List<Map<String, dynamic>> items, int unread) => {
      'notifications': items,
      'pagination': {'page': 1, 'per_page': 20, 'total': items.length, 'total_pages': 1},
      'unread_count': unread,
    };

final _before = _page([_n(3), _n(2, read: true), _n(1, read: true)], 1);
final _after = _page([_n(3)], 1);

bool _cleared(FakeApiClient f) =>
    f.calls.any((c) => c.method == 'DELETE' && c.path.endsWith('/notifications/read'));

void main() {
  late FakeApiClient fake;
  late NotificationListNotifier notifier;

  setUp(() async {
    fake = FakeApiClient()..reset();
    notifier = NotificationListNotifier(NotificationRepository(fake.apiClient));
    fake.enqueue(response: _before);
    await notifier.load();
  });

  test('clears on the server, then shows what is left', () async {
    fake.enqueue(response: {'deleted': 2});
    fake.enqueue(response: _after);
    expect(await notifier.clearRead(), 2);
    expect(_cleared(fake), isTrue);
    expect([for (final n in notifier.state.paged.items) n.id], [3]);
    expect(notifier.state.unreadCount, 1);
  });

  test('a failure reports null and keeps the list', () async {
    fake.enqueue(type: FakeResponseType.serverError);
    expect(await notifier.clearRead(), isNull);
    expect(notifier.state.paged.items.length, 3);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openMenuAndChoose(WidgetTester tester) async {
    fake.enqueue(response: _before); // the screen reloads on open
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationListProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: NotificationListScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Clear read notifications'));
    await settle(tester);
    expect(find.text('Clear read notifications?'), findsOneWidget);
  }

  testWidgets('Cancel deletes nothing', (tester) async {
    await openMenuAndChoose(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(_cleared(fake), isFalse);
    expect(find.text('Note 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Clear deletes the read ones and says how many', (tester) async {
    await openMenuAndChoose(tester);
    fake.enqueue(response: {'deleted': 2});
    fake.enqueue(response: _after);
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(_cleared(fake), isTrue);
    expect(find.text('Cleared 2 read notifications'), findsOneWidget);
    expect(find.text('Note 2'), findsNothing);
    expect(find.text('Note 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
