import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'recent_items_v1';
const _kMaxItems = 8;

enum RecentItemType { order, quotation, dispatch }

/// One entry in the "Continue Working" list -- recorded by a detail screen
/// each time it's opened (see order_detail_screen.dart, quotation_detail_
/// screen.dart, dispatch_detail_screen.dart), read back on the Home Action
/// Center so a user who got interrupted mid-task can jump straight back in
/// instead of re-navigating/re-searching for it.
class RecentItem {
  final RecentItemType type;
  final int id;
  final String title;
  final String subtitle;
  final DateTime viewedAt;

  const RecentItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.viewedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'viewedAt': viewedAt.toIso8601String(),
      };

  factory RecentItem.fromJson(Map<String, dynamic> j) => RecentItem(
        type: RecentItemType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => RecentItemType.order,
        ),
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        viewedAt:
            DateTime.tryParse(j['viewedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class RecentItemsNotifier extends StateNotifier<List<RecentItem>> {
  RecentItemsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    final items = raw
        .map((s) => RecentItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    if (mounted) state = items;
  }

  /// Moves this item to the front (deduping by type+id) and trims to
  /// [_kMaxItems]. Safe to call on every screen build -- SharedPreferences
  /// writes are cheap and local, and a detail screen doesn't rebuild often
  /// enough for that to matter in practice.
  Future<void> record(RecentItem item) async {
    final next = state.where((e) => !(e.type == item.type && e.id == item.id)).toList();
    next.insert(0, item);
    final trimmed = next.take(_kMaxItems).toList();
    state = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      trimmed.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

final recentItemsProvider =
    StateNotifierProvider<RecentItemsNotifier, List<RecentItem>>(
  (ref) => RecentItemsNotifier(),
);
