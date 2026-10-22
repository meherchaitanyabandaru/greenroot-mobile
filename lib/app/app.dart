import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/session_provider.dart';
import '../core/mango/mango_controller.dart';
import '../core/mango/mango_guides.dart';
import '../core/mango/mango_layer.dart';
import 'router.dart';

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
      }
    }
  }

  /// Who Ask Mango is helping on this screen, or null to hide it.
  MangoAudience? _mangoAudience() {
    final session = ref.read(sessionProvider);
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (!session.isAuthenticated) return path == '/login' ? MangoAudience.guest : null;
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(1);
        final cappedScale = scale > 1 ? 1.0 : scale;
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(cappedScale)),
          // Ask Mango sits above every screen; it adds nothing to them.
          child: MangoLayer(
            controller: mango,
            refresh: appRouter.routerDelegate,
            audience: _mangoAudience,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
