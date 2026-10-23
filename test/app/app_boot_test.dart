import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/app/app.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppConfig.init(EnvConfig.dev);
    AppLogger.init();
    ApiClient.init();
  });

  // Debug builds used to stop at a red screen ('!_dirty' while building the
  // app's MediaQuery): the Ask Mango layer called setState mid-build when
  // the router announced the first route.
  testWidgets('the app starts without framework errors', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GreenRootApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
