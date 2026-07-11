import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/notifications/notifications.dart';
import 'user_avatar.dart';

/// Persistent top bar used across all main tab screens.
/// Avatar (left) taps to /profile. Notification bell (right) taps to /notifications.
class GreenRootAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final PreferredSizeWidget? bottom;
  final List<Widget> extraActions;

  const GreenRootAppBar({
    super.key,
    this.title = 'GreenRoot',
    this.subtitle,
    this.bottom,
    this.extraActions = const [],
  });

  double get _toolbarHeight => subtitle != null ? 64.0 : kToolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationListProvider).unreadCount;

    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: _toolbarHeight,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: UserAvatar(
          size: 36,
          borderWidth: 1.5,
          onTap: () => context.push('/profile'),
        ),
      ),
      titleSpacing: 4,
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.h3),
                Text(
                  subtitle!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : Text(title, style: AppTypography.h3),
      centerTitle: false,
      actions: [
        ...extraActions,
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: Badge.count(
            count: unread,
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_none_rounded),
          ),
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 4),
      ],
      bottom: bottom,
    );
  }
}
