import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/network/api_client.dart';
import 'core/utilities/logger.dart';
import 'app/app.dart';

void main() => _run(EnvConfig.dev);

Future<void> _run(EnvConfig env) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init(env);
  AppLogger.init();
  ApiClient.init();

  AppLogger.i('Starting GreenRoot [${env.environment.name}]');

  runApp(
    const ProviderScope(
      child: GreenRootApp(),
    ),
  );
}
