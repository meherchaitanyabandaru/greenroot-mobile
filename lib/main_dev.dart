import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/network/api_client.dart';
import 'core/utilities/logger.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init(EnvConfig.dev);
  AppLogger.init();
  ApiClient.init();
  runApp(const ProviderScope(child: GreenRootApp()));
}
