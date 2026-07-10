import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'quotation_pinned_ids';

class QuotationPinsNotifier extends StateNotifier<Set<int>> {
  QuotationPinsNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    if (mounted) state = raw.map(int.parse).toSet();
  }

  Future<void> toggle(int id) async {
    final next = Set<int>.from(state);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, next.map((e) => e.toString()).toList());
  }

  bool isPinned(int id) => state.contains(id);
}

final quotationPinsProvider =
    StateNotifierProvider<QuotationPinsNotifier, Set<int>>(
  (ref) => QuotationPinsNotifier(),
);
