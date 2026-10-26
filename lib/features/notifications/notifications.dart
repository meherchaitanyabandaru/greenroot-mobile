import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/data/models/capabilities_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/models/pagination.dart';
import '../../core/network/api_client.dart';
import '../auth/presentation/providers/session_provider.dart';

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

  /// The record this notification is about ("quotation", "order",
  /// "dispatch"), from the API's data; null when it is not about one.
  final String? entity;
  final int? entityId;

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
    this.entity,
    this.entityId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    // data arrives as a JSON string ("{}" when there is no link).
    final raw = j['data'];
    Map<String, dynamic> data = const {};
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) data = decoded.cast<String, dynamic>();
    } catch (_) {}
    return AppNotification(
        entity: data['entity'] as String?,
        entityId: (data['id'] as num?)?.toInt(),
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
  }

  bool get isUnread => readAt == null;

  /// The same notification, read now. Keeps everything else, the link included.
  AppNotification asRead() => AppNotification(
        id: id,
        notificationCode: notificationCode,
        type: type,
        title: title,
        message: message,
        channel: channel,
        status: 'read',
        readAt: readAt ?? DateTime.now().toIso8601String(),
        createdAt: createdAt,
        entity: entity,
        entityId: entityId,
      );
}

/// Where tapping a notification goes, for this person: the driver's trip map,
/// the seller's dispatch page or the customer's delivery tracking.
String? notificationRoute(AppNotification n, UserCapabilities caps) {
  final id = n.entityId;
  if (id == null) return null;
  return switch (n.entity) {
    'quotation' => '/quotations/$id',
    'order' => '/orders/$id',
    'dispatch' => caps.isDriverOnly
        ? '/driver/trip/$id'
        : caps.canSell
            ? '/dispatches/$id'
            : '/dispatches/$id/buyer-track',
    _ => null,
  };
}

// ── Repository ────────────────────────────────────────────────────────────────

class NotificationRepository {
  final ApiClient _client;
  NotificationRepository(this._client);

  /// A page of notifications and the user's whole unread total (from the API,
  /// whatever the page or filter).
  Future<(List<AppNotification>, ApiPagination, int)> listNotifications({
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
                AppNotification.fromJson(e as Map<String, dynamic>),)
            .toList();
        final pagination =
            ApiPagination.fromJson(d['pagination'] as Map<String, dynamic>);
        final unread = (d['unread_count'] as num?)?.toInt() ??
            items.where((n) => n.isUnread).length;
        return (items, pagination, unread);
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
      final (items, pagination, unreadCount) = await _repo.listNotifications(
        page: 1,
        unreadOnly: uo ? true : null,
      );
      _page = 1;
      state = state.copyWith(
        unreadCount: unreadCount,
        paged: PagedState(
          items: items,
          isLoading: false,
          isLoadingMore: false,
          hasMore: pagination.hasMore,
        ),
      );
    } on AppError catch (e) {
      state = state.copyWith(
          paged: state.paged.copyWith(isLoading: false, error: e),);
    }
  }

  Future<void> loadMore() async {
    if (state.paged.isLoadingMore || !state.paged.hasMore) return;
    state = state.copyWith(paged: state.paged.copyWith(isLoadingMore: true));
    try {
      final (items, pagination, unreadCount) = await _repo.listNotifications(
        page: _page + 1,
        unreadOnly: state.unreadOnly ? true : null,
      );
      _page++;
      state = state.copyWith(
        unreadCount: unreadCount,
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
          .map((n) => n.id == id ? n.asRead() : n)
          .toList();
      state = state.copyWith(
        unreadCount: _countWithout(id),
        paged: state.paged.copyWith(items: updatedItems),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      final updatedItems = state.paged.items
          .map((n) => n.asRead())
          .toList();
      state = state.copyWith(
        unreadCount: 0,
        paged: state.paged.copyWith(items: updatedItems),
      );
    } catch (_) {}
  }

  /// The unread total once [id] is read or gone (it counted only if unread).
  int _countWithout(int id) {
    final was = state.paged.items.where((n) => n.id == id).firstOrNull;
    final count = state.unreadCount - (was != null && was.isUnread ? 1 : 0);
    return count < 0 ? 0 : count;
  }

  // ── Swipe to delete with Undo: hide now, delete on the server only once the
  // Undo window has passed ([commitDelete]), or put it back ([restore]).

  /// Takes [id] out of the list; returns it and where it was, to restore.
  (AppNotification, int)? hide(int id) {
    final items = state.paged.items;
    final index = items.indexWhere((n) => n.id == id);
    if (index < 0) return null;
    final n = items[index];
    state = state.copyWith(
      unreadCount: _countWithout(id),
      paged: state.paged.copyWith(items: [...items]..removeAt(index)),
    );
    return (n, index);
  }

  void restore(AppNotification n, int index) {
    final items = state.paged.items;
    if (items.any((x) => x.id == n.id)) return; // a reload already brought it back
    state = state.copyWith(
      unreadCount: state.unreadCount + (n.isUnread ? 1 : 0),
      paged: state.paged.copyWith(
        items: [...items]..insert(index.clamp(0, items.length), n),
      ),
    );
  }

  /// Deletes a hidden notification on the server; puts it back if that fails.
  Future<bool> commitDelete(AppNotification n, int index) async {
    try {
      await _repo.deleteNotification(n.id);
      return true;
    } on AppError {
      restore(n, index);
      return false;
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      await _repo.deleteNotification(id);
      final updatedItems =
          state.paged.items.where((n) => n.id != id).toList();
      state = state.copyWith(
        unreadCount: _countWithout(id),
        paged: state.paged.copyWith(items: updatedItems),
      );
    } catch (_) {}
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>(
        (ref) {
  // Rebuilt per signed-in user and loaded at once, so the bell's badge is
  // right from launch (and never shows the previous account's count).
  final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
  final notifier =
      NotificationListNotifier(ref.watch(notificationRepositoryProvider));
  if (userId != null) notifier.load();
  return notifier;
});
