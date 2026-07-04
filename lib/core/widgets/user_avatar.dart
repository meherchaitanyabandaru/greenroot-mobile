import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../features/auth/data/models/capabilities_model.dart';
import '../../features/auth/data/models/user_models.dart';
import '../../features/auth/presentation/providers/session_provider.dart';

/// Reusable avatar that shows the user's profile photo, falling back to a
/// role-based icon when no photo is available or when the image fails to load.
class UserAvatar extends ConsumerWidget {
  final double size;
  final double borderWidth;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.size = 42,
    this.borderWidth = 1.5,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return _AvatarView(
      user: session.user,
      caps: session.capabilities,
      size: size,
      borderWidth: borderWidth,
      onTap: onTap,
    );
  }
}

class _AvatarView extends StatelessWidget {
  final UserProfile? user;
  final UserCapabilities caps;
  final double size;
  final double borderWidth;
  final VoidCallback? onTap;

  const _AvatarView({
    required this.user,
    required this.caps,
    required this.size,
    required this.borderWidth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = user?.profileImageUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    Widget inner = hasPhoto
        ? Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(caps, size),
          )
        : _placeholder(caps, size);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.forest100,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryMain,
            width: borderWidth,
          ),
        ),
        child: ClipOval(child: inner),
      ),
    );
  }

  static Widget _placeholder(UserCapabilities caps, double size) {
    final IconData icon;
    if (caps.isDriverOnly) {
      icon = Icons.local_shipping_outlined;
    } else if (caps.isNurseryOwner) {
      icon = Icons.local_florist_rounded;
    } else if (caps.isManager) {
      icon = Icons.manage_accounts_rounded;
    } else {
      icon = Icons.shopping_bag_outlined;
    }
    return Center(
      child: Icon(icon, color: AppColors.primaryMain, size: size * 0.48),
    );
  }
}
