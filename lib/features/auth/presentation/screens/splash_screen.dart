import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/rbac/roles.dart';
import '../providers/session_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static void routeAfterLogin(BuildContext context, SessionState session) =>
      _routeByCapabilities(context, session);

  static void _routeByCapabilities(BuildContext context, SessionState session) {
    final caps = session.capabilities;
    if (caps.hasPendingNursery) {
      context.go('/nursery/pending');
      return;
    }
    if (caps.hasRejectedNursery) {
      context.go('/nursery/rejected');
      return;
    }
    if (session.hasMultipleWorkspaces && session.activeRole == null) {
      context.go('/workspace-select');
      return;
    }
    if (session.roles.hasAnyRole([AppRole.admin, AppRole.superAdmin]) &&
        session.mobileWorkspaces.isEmpty) {
      context.go('/home/admin');
      return;
    }
    context.go('/home');
  }

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
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),);

    _animController.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    await ref.read(sessionProvider.notifier).bootstrap();
    if (!mounted) return;
    _navigate();
  }

  void _navigate() {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      context.go('/login');
      return;
    }
    SplashScreen.routeAfterLogin(context, session);
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
