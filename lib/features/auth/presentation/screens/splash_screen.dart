import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/pending_deep_link.dart';
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
    if (!(session.user?.hasRealFirstName ?? false)) {
      context.go('/create-profile');
      return;
    }
    if (caps.hasPendingNursery) {
      context.go('/nursery/pending');
      return;
    }
    if (caps.hasRejectedNursery) {
      context.go('/nursery/rejected');
      return;
    }
    if (session.mobileWorkspaces.isEmpty &&
        session.hasPendingDriverApplication) {
      context.go('/driver/application-status');
      return;
    }
    if (session.mobileWorkspaces.isEmpty &&
        session.hasRejectedDriverApplication) {
      context.go('/driver/application-status');
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
    // New user with no completed first activity yet — prompt them to pick one.
    if (session.mobileWorkspaces.isEmpty &&
        !session.hasCompletedOnboarding &&
        !session.roles.hasAnyRole([AppRole.admin, AppRole.superAdmin])) {
      context.go('/select-activity');
      return;
    }
    context.go(PendingDeepLink.take() ?? '/home');
  }

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

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

  Future<void> _retry() async {
    setState(() => _offline = false);
    await ref.read(sessionProvider.notifier).bootstrap();
    if (mounted) _navigate();
  }

  void _navigate() {
    final session = ref.read(sessionProvider);
    // Offline at launch: keep the signed-in session and offer a retry
    // instead of sending the user back to OTP sign-in.
    if (session.isOffline) {
      setState(() => _offline = true);
      return;
    }
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
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
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
                if (_offline) ...[
                  const SizedBox(height: 32),
                  Text(
                    'No connection. Check your internet and try again.',
                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton(
                      onPressed: _retry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
