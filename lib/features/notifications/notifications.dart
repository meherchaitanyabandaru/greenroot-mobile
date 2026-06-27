import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AppNotification {
  final int id;
  final String notificationCode;
  final String type;
  final String? title;
  final String? message;
  final String channel;
  final String status;
  final String? readAt;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.notificationCode,
    required this.type,
    this.title,
    this.message,
    required this.channel,
    required this.status,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        notificationCode: j['notification_code'] as String,
        type: j['notification_type'] as String,
        title: j['title'] as String?,
        message: j['message'] as String?,
        channel: j['channel'] as String? ?? 'in_app',
        status: j['notification_status'] as String,
        readAt: j['read_at'] as String?,
        createdAt: j['created_at'] as String,
      );

  bool get isUnread => readAt == null;
}

// ── Repository ────────────────────────────────────────────────────────────────

class NotificationRepository {
  final ApiClient _client;
  NotificationRepository(this._client);

  Future<(List<AppNotification>, ApiPagination)> listNotifications({
    int page = 1,
    int perPage = 20,
    bool? unreadOnly,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (unreadOnly == true) 'unread': true,
    };
    return _client.get(
      ApiConstants.notifications,
      queryParameters: params,
      fromJson: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['notifications'] as List<dynamic>)
            .map((e) =>
                AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        return (items, pagination);
      },
    );
  }

  Future<void> markRead(int id) async {
    await _client.put<dynamic>(ApiConstants.markNotificationRead(id));
  }

  Future<void> markAllRead() async {
    await _client.put<dynamic>(ApiConstants.markAllNotificationsRead);
  }

  Future<void> deleteNotification(int id) async {
    await _client.delete<dynamic>(ApiConstants.deleteNotification(id));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ApiClient.instance),
);

class NotificationListState {
  final PagedState<AppNotification> paged;
  final bool unreadOnly;
  final int unreadCount;

  const NotificationListState({
    required this.paged,
    this.unreadOnly = false,
    this.unreadCount = 0,
  });

  NotificationListState copyWith({
    PagedState<AppNotification>? paged,
    bool? unreadOnly,
    int? unreadCount,
  }) =>
      NotificationListState(
        paged: paged ?? this.paged,
        unreadOnly: unreadOnly ?? this.unreadOnly,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class NotificationListNotifier
    extends StateNotifier<NotificationListState> {
  final NotificationRepository _repo;
  int _page = 0;

  NotificationListNotifier(this._repo)
      : super(NotificationListState(paged: PagedState.initial()));

  Future<void> load({bool? unreadOnly}) async {
    final uo = unreadOnly ?? state.unreadOnly;
    state = state.copyWith(
      unreadOnly: uo,
      paged: state.paged.copyWith(isLoading: true, clearError: true),
    );
    try {
      final (items, pagination) = await _repo.listNotifications(
        page: 1,
        unreadOnly: uo ? true : null,
      );
      _page = 1;
      final unreadCount = items.where((n) => n.isUnread).length;
      state = state.copyWith(
        unreadCount: uo ? items.length : unreadCount,
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination) = await _repo.listNotifications(
        page: _page + 1,
        unreadOnly: state.unreadOnly ? true : null,
      );
      _page++;
      state = state.copyWith(
        paged: state.paged.copyWith(
          items: [...state.paged.items, ...items],
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError {
      state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: false));
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _repo.markRead(id);
      // Update local state
      final updatedItems = state.paged.items
          .map((n) => n.id == id
              ? AppNotification(
                  id: n.id,
                  notificationCode: n.notificationCode,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  channel: n.channel,
                  status: 'read',
                  readAt: DateTime.now().toIso8601String(),
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
      final unreadCount = updatedItems.where((n) => n.isUnread).length;
      state = state.copyWith(
        unreadCount: unreadCount,
        paged: state.paged.copyWith(items: updatedItems),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      final updatedItems = state.paged.items
          .map((n) => AppNotification(
                id: n.id,
                notificationCode: n.notificationCode,
                type: n.type,
                title: n.title,
                message: n.message,
                channel: n.channel,
                status: 'read',
                readAt: DateTime.now().toIso8601String(),
                createdAt: n.createdAt,
              ))
          .toList();
      state = state.copyWith(
        unreadCount: 0,
        paged: state.paged.copyWith(items: updatedItems),
      );
    } catch (_) {}
  }

  Future<void> deleteNotification(int id) async {
    try {
      await _repo.deleteNotification(id);
      final updatedItems =
          state.paged.items.where((n) => n.id != id).toList();
      final unreadCount = updatedItems.where((n) => n.isUnread).length;
      state = state.copyWith(
        unreadCount: unreadCount,
        paged: state.paged.copyWith(items: updatedItems),
      );
    } catch (_) {}
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>(
        (ref) {
  return NotificationListNotifier(ref.watch(notificationRepositoryProvider));
});
