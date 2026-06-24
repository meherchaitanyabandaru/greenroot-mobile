import 'environment.dart';

class AppConfig {
  static late EnvConfig _config;

  static void init(EnvConfig config) {
    _config = config;
  }

  static EnvConfig get current => _config;

  static String get apiBaseUrl => _config.apiBaseUrl;
  static bool get enableLogging => _config.enableLogging;
  static String get appName => _config.appName;
  static bool get isDev => _config.isDev;
}
