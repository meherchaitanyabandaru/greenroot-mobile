enum AppEnvironment { dev, qa, production }

class EnvConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String appName;
  final bool enableLogging;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    required this.enableLogging,
  });

  static const dev = EnvConfig(
    environment: AppEnvironment.dev,
    apiBaseUrl: 'http://127.0.0.1:8080', // adb reverse tcp:8080 tcp:8080 tunnels to Mac
    appName: 'GreenRoot Dev',
    enableLogging: true,
  );

  static const qa = EnvConfig(
    environment: AppEnvironment.qa,
    apiBaseUrl: 'https://api-qa.greenroot.in',
    appName: 'GreenRoot QA',
    enableLogging: true,
  );

  static const production = EnvConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: 'https://api.greenroot.in',
    appName: 'GreenRoot',
    enableLogging: false,
  );

  bool get isDev => environment == AppEnvironment.dev;
  bool get isProduction => environment == AppEnvironment.production;
}
