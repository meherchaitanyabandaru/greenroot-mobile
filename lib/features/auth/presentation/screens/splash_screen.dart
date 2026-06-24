import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _animController.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    await ref.read(sessionProvider.notifier).bootstrap();
    await ref.read(activeRoleProvider.notifier).loadSavedRole();

    if (!mounted) return;
    _navigate();
  }

  void _navigate() {
    final session    = ref.read(sessionProvider);
    final activeRole = ref.read(activeRoleProvider);

    if (!session.isAuthenticated) {
      context.go('/login');
      return;
    }

    final mobileRoles = session.roles.where((r) => r.isMobileRole).toList();

    if (activeRole != null && mobileRoles.contains(activeRole)) {
      context.go(_dashboardRoute(activeRole));
      return;
    }

    if (mobileRoles.length == 1) {
      context.go(_dashboardRoute(mobileRoles.first));
      return;
    }

    context.go('/role-select');
  }

  String _dashboardRoute(role) {
    return switch (role.value) {
      'BUYER'              => '/home/buyer',
      'NURSERY_OWNER'      => '/home/nursery-owner',
      'MANAGER'            => '/home/manager',
      'DRIVER'             => '/home/driver',
      'TRANSPORT_PROVIDER' => '/home/transport-provider',
      'ADMIN'              => '/home/admin',
      'SUPER_ADMIN'        => '/home/super-admin',
      _                    => '/home/buyer',
    };
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryMain,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo mark
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.accentMain,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      'GR',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest950,
                        fontFamily: 'Inter',
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'GreenRoot',
                  style: AppTypography.h1.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Nursery Platform',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
