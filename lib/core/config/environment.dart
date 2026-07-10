enum AppEnvironment { dev, qa, production }

class EnvConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String webBaseUrl; // base URL of this web app — used to build QR verification URLs
  final String appName;
  final bool enableLogging;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.webBaseUrl,
    required this.appName,
    required this.enableLogging,
  });

  static const dev = EnvConfig(
    environment: AppEnvironment.dev,
    apiBaseUrl: 'http://localhost:8080', // use LAN IP (e.g. 192.168.1.x:8080) for physical device testing
    webBaseUrl: 'http://localhost:4040',
    appName: 'GreenRoot Dev',
    enableLogging: true,
  );

  static const qa = EnvConfig(
    environment: AppEnvironment.qa,
    apiBaseUrl: 'https://api-qa.greenroot.in',
    webBaseUrl: 'https://app-qa.greenroot.in',
    appName: 'GreenRoot QA',
    enableLogging: true,
  );

  static const production = EnvConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: 'https://api.greenroot.in',
    webBaseUrl: 'https://app.greenroot.in',
    appName: 'GreenRoot',
    enableLogging: false,
  );

  bool get isDev => environment == AppEnvironment.dev;
  bool get isProduction => environment == AppEnvironment.production;
}
