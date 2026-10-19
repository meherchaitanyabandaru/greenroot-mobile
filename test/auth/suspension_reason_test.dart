import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/core/storage/secure_storage_service.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';
import 'package:greenroot_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:greenroot_mobile/features/auth/data/models/auth_models.dart';
import 'package:greenroot_mobile/features/auth/data/models/user_models.dart';
import 'package:greenroot_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:greenroot_mobile/features/auth/presentation/providers/session_provider.dart';

/// The refresh call is the only response that carries the suspension reason;
/// /users/me answers 403 without it.
class _SuspendedRemote extends AuthRemoteDataSource {
  _SuspendedRemote() : super(ApiClient.instance);

  @override
  Future<AuthResponse> refreshToken(String refreshToken) async =>
      throw AccountSuspendedError(reason: 'KYC documents expired', suspendedAt: DateTime(2026, 10, 19));

  @override
  Future<UserProfile> getMe() async => throw const AccountSuspendedError();
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppConfig.init(EnvConfig.dev);
    AppLogger.init();
    ApiClient.init();
  });

  test('bootstrap keeps the suspension reason from the refresh response', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await SecureStorageService.saveSession(accessToken: 'a', refreshToken: 'r', userId: 2);
    final notifier = SessionNotifier(AuthRepository(_SuspendedRemote()));
    await notifier.bootstrap();
    expect(notifier.state.isSuspended, isTrue);
    expect(notifier.state.suspensionInfo?.reason, 'KYC documents expired');
  });
}
