import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';

void main() {
  setUp(() {
    AppConfig.init(EnvConfig.dev);
    AppLogger.init();
    ApiClient.init();
  });

  test('AppConfig initialises with dev settings', () {
    expect(AppConfig.apiBaseUrl, 'http://127.0.0.1:8080');
    expect(AppConfig.enableLogging, isTrue);
    expect(AppConfig.isDev, isTrue);
  });
}
