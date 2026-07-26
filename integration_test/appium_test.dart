// Entrypoint for Appium's Flutter Integration Driver (see /greenroot-e2e).
//
// This mirrors lib/main.dart's real bootstrap (config/logger/API client
// init + ProviderScope) so the app under Appium behaves identically to a
// normal launch — the only difference is appium_flutter_server embeds an
// HTTP control server that Appium's driver talks to.
//
// Build: from greenroot-mobile/android, run
//   ./gradlew app:assembleDebug -Ptarget=`pwd`/../integration_test/appium_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appium_flutter_server/appium_flutter_server.dart';

import 'package:greenroot_mobile/app/app.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';

void main() {
  initializeTest(
    callback: (WidgetTester tester) async {
      AppConfig.init(EnvConfig.dev);
      AppLogger.init();
      ApiClient.init();

      await tester.pumpWidget(
        const ProviderScope(child: GreenRootApp()),
      );
    },
  );
}
