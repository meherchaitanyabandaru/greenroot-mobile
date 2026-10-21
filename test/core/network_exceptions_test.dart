import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/core/network/network_exceptions.dart';
import 'package:greenroot_mobile/core/config/app_config.dart';
import 'package:greenroot_mobile/core/config/environment.dart';
import 'package:greenroot_mobile/core/utilities/logger.dart';

AppError _map(int status, String code) {
  final req = RequestOptions(path: '/api/v1/quotations');
  return NetworkExceptions.fromDioException(DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: req,
      statusCode: status,
      data: {
        'error': {'code': code, 'message': 'raw server text'},
      },
    ),
  ),);
}

void main() {
  setUpAll(() {
    AppConfig.init(EnvConfig.dev);
    AppLogger.init();
  });

  // The subscription gate (402) must tell owners and managers what to do,
  // not surface a generic server error.
  test('402 subscription_required says the owner can renew', () {
    final e = _map(402, 'subscription_required');
    expect(e, isA<ForbiddenError>());
    expect(e.message, contains("isn't active"));
    expect(e.message, contains('Profile → Subscription'));
  });

  test('402 subscription_expired says it expired', () {
    expect(_map(402, 'subscription_expired').message, contains('expired'));
  });
}
