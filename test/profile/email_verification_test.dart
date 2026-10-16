// Email verification: send-code then verify against /users/me/email/*.

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/constants/api_constants.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/auth/presentation/providers/auth_provider.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;

  setUp(() => fake = FakeApiClient());

  test('send-code returns the dev code in mock mode, null when live', () async {
    final repo = makeTestContainer(fake.apiClient).read(authRepositoryProvider);

    fake.enqueue(response: {'message': 'Verification code sent', 'mock_code': '123456', 'delivered_to': 'ravi@example.in'});
    expect(await repo.sendEmailCode('ravi@example.in'), '123456');

    fake.enqueue(response: {'message': 'Verification code sent', 'delivered_to': 'ravi@example.in'});
    expect(await repo.sendEmailCode('ravi@example.in'), isNull);

    expect(fake.calls.map((c) => '${c.method} ${c.path}'), everyElement('POST ${ApiConstants.usersMeEmailSendCode}'));
  });

  test('verify returns the profile with email_verified set', () async {
    final repo = makeTestContainer(fake.apiClient).read(authRepositoryProvider);
    fake.enqueue(response: {
      'user': {
        ...(kUserMeResponse['user']! as Map<String, dynamic>),
        'email': 'ravi@example.in',
        'email_verified': true,
      },
    },);

    final user = await repo.verifyEmail('ravi@example.in', '123456');

    expect(user.email, 'ravi@example.in');
    expect(user.emailVerified, isTrue);
    expect(fake.calls.single.path, ApiConstants.usersMeEmailVerify);
  });

  test('wrong code and taken email surface as errors', () async {
    final repo = makeTestContainer(fake.apiClient).read(authRepositoryProvider);

    fake.enqueue(type: FakeResponseType.validationError);
    await expectLater(repo.verifyEmail('ravi@example.in', '000000'), throwsA(isA<ValidationError>()));

    fake.enqueue(type: FakeResponseType.conflict);
    await expectLater(repo.sendEmailCode('taken@example.in'), throwsA(isA<AppError>()));
  });
}
