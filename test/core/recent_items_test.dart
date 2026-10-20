import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/services/recent_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

RecentItem _order(int id) => RecentItem(
      type: RecentItemType.order,
      id: id,
      title: 'ORD-$id',
      subtitle: '',
      viewedAt: DateTime(2026, 10, 20),
    );

Future<List<RecentItem>> _loaded(int? userId) async {
  final n = RecentItemsNotifier(userId);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return n.state;
}

void main() {
  test("one account's recent items never show for another account", () async {
    SharedPreferences.setMockInitialValues({
      // The old device-wide list, written before lists were per user.
      'recent_items_v1': ['{"type":"order","id":99,"title":"ORD-99","subtitle":"","viewedAt":"2026-10-19T10:00:00Z"}'],
    });

    final a = RecentItemsNotifier(1);
    await Future<void>.delayed(Duration.zero);
    await a.record(_order(10));

    expect((await _loaded(1)).map((e) => e.id), [10]);
    expect(await _loaded(2), isEmpty, reason: 'user 2 must not see user 1');
    expect(await _loaded(null), isEmpty, reason: 'nothing while signed out');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('recent_items_v1'), isNull, reason: 'the shared legacy list is deleted');
  });

  test('signed out: recording does nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final n = RecentItemsNotifier(null);
    await n.record(_order(5));
    expect(n.state, isEmpty);
  });
}
