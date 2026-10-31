import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/session_provider.dart';
import '../core/mango/mango_controller.dart';
import '../core/mango/mango_guides.dart';
import '../core/mango/mango_layer.dart';
import '../core/update/update_gate.dart';
import 'router.dart';
import 'pending_deep_link.dart';
import '../core/mango/mango_popups.dart';
import '../core/feedback/app_haptics.dart';
import '../core/push/push_service.dart';
import '../features/notifications/notifications.dart';

/// Shows banners from outside any screen (pushes arriving while open).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class GreenRootApp extends ConsumerStatefulWidget {
  const GreenRootApp({super.key});

  @override
  ConsumerState<GreenRootApp> createState() => _GreenRootAppState();
}

class _GreenRootAppState extends ConsumerState<GreenRootApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushService.instance.onForeground = _showForegroundPush;
    PushService.instance.onNotificationTap = _handlePushTap;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.instance.checkInitialMessage();
    });
  }

  void _handlePushTap(PushMessage m) {
    final session = ref.read(sessionProvider);
    final route = routeForPushMessage(m, session.capabilities);
    if (route == null) {
      if (session.isAuthenticated) {
        appRouter.push('/notifications');
      }
      return;
    }

    if (session.isAuthenticated) {
      appRouter.push(route);
    } else {
      PendingDeepLink.remember(Uri.parse(route));
    }
  }

  /// A push while the app is open: Android shows nothing on its own, so show
  /// it as a banner with a haptic, and refresh the bell's unread count.
  void _showForegroundPush(PushMessage m) {
    final text = [m.title, m.body]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(' — ');
    if (text.isEmpty) return;
    AppHaptics.success();
    ref.read(notificationListProvider.notifier).load();

    final session = ref.read(sessionProvider);
    final route = routeForPushMessage(m, session.capabilities);

    appMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'View',
        onPressed: () {
          if (route != null) {
            appRouter.push(route);
          } else {
            appRouter.push('/notifications');
          }
        },
      ),
    ),);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Fires once when app returns to foreground — no polling, no battery drain.
  // Re-bootstraps only when authenticated so a mid-background suspension is
  // caught the moment the user opens the app again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final session = ref.read(sessionProvider);
      if (session.isAuthenticated) {
        ref.read(sessionProvider.notifier).bootstrap();
        // Pushes may be off or missed: recount the bell when the user is back.
        ref.read(notificationListProvider.notifier).load();
      }
    }
  }

  /// Who Ask Mango is helping on this screen, or null to hide it.
  MangoAudience? _mangoAudience() {
    final session = ref.read(sessionProvider);
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (!session.isAuthenticated) return path == '/login' ? MangoAudience.guest : null;
    // Signing up: a few simple choices, nothing to guide yet, and the button
    // sat on the role cards.
    const signingUp = {
      '/create-profile',
      '/account-ready',
      '/select-activity',
      '/workspace-select',
    };
    if (signingUp.contains(path)) {
      return null;
    }
    final caps = session.capabilities;
    if (caps.isNurseryOwner) return MangoAudience.owner;
    if (caps.isManager) return MangoAudience.manager;
    if (caps.hasDriverProfile) return MangoAudience.driver;
    return MangoAudience.customer;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionProvider); // Ask Mango follows sign-in and role changes
    ref.listen(sessionProvider, (_, __) => appRouter.refresh());

    return MaterialApp.router(
      title: 'GreenRoot',
      scaffoldMessengerKey: appMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(1);
        // Honour the phone's larger font up to 130% (readability); beyond that
        // layouts break. test/screens/small_screen_test.dart checks 130%.
        final cappedScale = scale > 1.3 ? 1.3 : scale;
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(cappedScale)),
          // Below the API's minimum version only the update screen shows.
          child: UpdateGate(
            // Ask Mango sits above every screen; it adds nothing to them.
            child: MangoLayer(
              controller: mango,
              refresh: Listenable.merge(
                  [appRouter.routerDelegate, mangoPopups.open],),
              audience: _mangoAudience,
              onAsk: () => appRouter.push('/mango'),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
