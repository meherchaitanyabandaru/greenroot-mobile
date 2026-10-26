import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'notifications.dart';
import '../../core/widgets/app_loader.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(notificationListProvider.notifier).load(),);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(notificationListProvider.notifier).loadMore();
      }
    });
  }

  Future<void> _clearRead() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear read notifications?'),
        content: const Text(
            'All notifications you have read will be deleted. Unread ones stay.',),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final deleted =
        await ref.read(notificationListProvider.notifier).clearRead();
    messenger.showSnackBar(SnackBar(
      content: Text(deleted == null
          ? 'Could not clear notifications. Try again.'
          : deleted == 0
              ? 'No read notifications to clear'
              : 'Cleared $deleted read notification${deleted == 1 ? '' : 's'}',),
    ),);
  }

  // Gone at once; deleted on the server only if Undo is not tapped in time.
  void _deleteWithUndo(int id) {
    final notifier = ref.read(notificationListProvider.notifier);
    final hidden = notifier.hide(id);
    if (hidden == null) return;
    final (n, index) = hidden;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            duration: const Duration(seconds: 4),
            persist: false, // with an action it would otherwise wait forever
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => notifier.restore(n, index),
            ),
          ),
        )
        .closed
        .then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      if (!await notifier.commitDelete(n, index)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListProvider);
    final paged = state.paged;
    // The server's total, so older unread ones (not loaded yet) still count.
    final hasUnread = state.unreadCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () =>
                  ref.read(notificationListProvider.notifier).markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.primaryMain),
              ),
            ),
          // Unread toggle
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              icon: Icon(
                state.unreadOnly
                    ? Icons.filter_list_rounded
                    : Icons.filter_list_outlined,
                color: state.unreadOnly
                    ? AppColors.primaryMain
                    : AppColors.textSecondary,
              ),
              tooltip: state.unreadOnly ? 'Show all' : 'Show unread only',
              onPressed: () => ref
                  .read(notificationListProvider.notifier)
                  .load(unreadOnly: !state.unreadOnly),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (_) => _clearRead(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear read notifications')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationListProvider.notifier).load(),
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            if (paged.isLoading)
              const SliverFillRemaining(
                child: Center(
                    child:
                        AppLoader(),),
              )
            else if (paged.error != null && paged.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textMuted,),
                      const SizedBox(height: AppSpacing.md),
                      Text(paged.error!.message, style: AppTypography.body),
                      TextButton(
                        onPressed: () =>
                            ref.read(notificationListProvider.notifier).load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (paged.items.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 48, color: AppColors.textMuted,),
                      SizedBox(height: AppSpacing.md),
                      Text('No notifications', style: AppTypography.h4),
                      SizedBox(height: AppSpacing.sm),
                      Text("You're all caught up!",
                          style: AppTypography.bodySmall,),
                    ],
                  ),
                ),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Dismissible(
                    key: ValueKey(paged.items[i].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.red600,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, semanticLabel: 'Delete',),
                    ),
                    onDismissed: (_) => _deleteWithUndo(paged.items[i].id),
                    child: _NotificationTile(
                      notification: paged.items[i],
                      onTap: () {
                        final n = paged.items[i];
                        if (n.isUnread) {
                          ref.read(notificationListProvider.notifier).markRead(n.id);
                        }
                        final route = notificationRoute(
                            n, ref.read(sessionProvider).capabilities,);
                        if (route != null) context.push(route);
                      },
                    ),
                  ),
                  childCount: paged.items.length,
                ),
              ),
              if (paged.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.x2l),
                    child: Center(
                        child: AppLoader(size: 28),),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x3l)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile(
      {required this.notification, required this.onTap,});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(notification.createdAt);
    final timeStr = date != null ? _timeAgo(date) : '';
    final isUnread = notification.isUnread;

    return InkWell(
      // Unread: tap marks it read; linked ones also open their record.
      onTap: isUnread || notification.entityId != null ? onTap : null,
      child: Container(
        color: isUnread
            ? AppColors.primaryLight.withValues(alpha: 0.4)
            : AppColors.background,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md,),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: notification.type),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: AppSpacing.sm),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryMain,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          notification.title ?? _typeLabel(notification.type),
                          style: AppTypography.label.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (notification.message != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      notification.message!,
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary, height: 1.4,),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  // The icon and title already say what kind it is; a badge
                  // with the raw type ("order delivered") only repeated it.
                  Text(timeStr,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type.toUpperCase()) {
        'ORDER' => 'Order Update',
        'DISPATCH' => 'Dispatch Update',
        'REQUEST' => 'Plant Request',
        'PAYMENT' => 'Payment',
        _ => 'Notification',
      };

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(date.toLocal());
  }
}

class _TypeIcon extends StatelessWidget {
  final String type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _iconData;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: fg),
    );
  }

  (IconData, Color, Color) get _iconData => switch (type.toUpperCase()) {
        'ORDER' => (Icons.shopping_bag_outlined, AppColors.blue100, AppColors.blue600),
        'DISPATCH' => (Icons.local_shipping_outlined, AppColors.amber100, AppColors.amber600),
        'REQUEST' => (Icons.assignment_outlined, AppColors.forest100, AppColors.primaryMain),
        'PAYMENT' => (Icons.payment_outlined, AppColors.teal100, AppColors.teal700),
        _ => (Icons.notifications_outlined, AppColors.slate100, AppColors.textSecondary),
      };
}
