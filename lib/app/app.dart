import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class GreenRootApp extends ConsumerWidget {
  const GreenRootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
