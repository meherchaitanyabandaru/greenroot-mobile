import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../errors/app_error.dart';
import '../models/pagination.dart';

/// Generic paginated list notifier.
///
/// Eliminates boilerplate: pass a [fetch] function and optional [idOf] extractor.
/// State is [PagedState<T>] directly — no wrapper class needed.
///
/// Usage:
/// ```dart
/// class _MyNotifier extends PagedNotifier<Order> {
///   _MyNotifier(OrderRepository repo)
///       : super(
///           fetch: (p, pp) => repo.listOrders(page: p, perPage: pp),
///           idOf: (o) => o.id,
///         );
/// }
/// final _myProvider = StateNotifierProvider.autoDispose<_MyNotifier, PagedState<Order>>(
///   (ref) => _MyNotifier(ref.watch(orderRepositoryProvider)),
/// );
/// ```
abstract class PagedNotifier<T> extends StateNotifier<PagedState<T>> {
  final Future<(List<T>, ApiPagination)> Function(int page, int perPage) _fetch;
  final int Function(T item)? _idOf;
  int _page = 0;

  PagedNotifier({
    required Future<(List<T>, ApiPagination)> Function(int page, int perPage) fetch,
    int Function(T item)? idOf,
  })  : _fetch = fetch,
        _idOf = idOf,
        super(PagedState.initial());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final (items, pagination) = await _fetch(1, 20);
      _page = 1;
      state = PagedState(
        items: items,
        isLoading: false,
        isLoadingMore: false,
        hasMore: pagination.hasMore,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final (items, pagination) = await _fetch(_page + 1, 20);
      _page++;
      state = state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        hasMore: pagination.hasMore,
      );
    } on AppError {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void updateItem(T updated) {
    final idOf = _idOf;
    if (idOf == null) return;
    final id = idOf(updated);
    state = state.copyWith(
      items: state.items.map((i) => idOf(i) == id ? updated : i).toList(),
    );
  }

  void removeItem(int id) {
    final idOf = _idOf;
    if (idOf == null) return;
    state = state.copyWith(
      items: state.items.where((i) => idOf(i) != id).toList(),
    );
  }
}
