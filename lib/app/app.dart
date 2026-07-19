import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/session_provider.dart';
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

  @override
  Widget build(BuildContext context) {
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
