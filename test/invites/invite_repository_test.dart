// Unit tests for InviteRepository — covers:
//   - sendInvite success returns invite map
//   - duplicate invite (422) → ValidationError
//   - 403 → ForbiddenError
//   - provider override verified — no direct singleton call

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/connections/invite_repository.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/test_data.dart';
import '../helpers/test_provider_container.dart';

void main() {
  late FakeApiClient fake;

  setUp(() {
    fake = FakeApiClient();
  });

  group('InviteRepository.sendInvite', () {
    test('success returns invite map with id', () async {
      fake.enqueue(response: inviteResponse());
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(inviteRepositoryProvider);

      final result = await repo.sendInvite(
        inviteType: 'MANAGER',
        nurseryId: kTestNurseryId,
        targetMobile: '9200000000',
        targetName: 'Gumastha Manager',
      );

      expect(result['id'], kTestInviteId);
      expect(result['invite_type'], 'MANAGER');
    });

    test('sendInvite without targetName succeeds', () async {
      fake.enqueue(response: inviteResponse());
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(inviteRepositoryProvider);

      final result = await repo.sendInvite(
        inviteType: 'BUYER',
        nurseryId: kTestNurseryId,
        targetMobile: null,
      );

      expect(result, isA<Map<String, dynamic>>());
    });

    test('duplicate invite (422) → ValidationError', () async {
      fake.enqueue(type: FakeResponseType.validationError);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(inviteRepositoryProvider);

      expect(
        () => repo.sendInvite(
          inviteType: 'MANAGER',
          nurseryId: kTestNurseryId,
          targetMobile: '9200000000',
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('403 Forbidden → ForbiddenError', () async {
      fake.enqueue(type: FakeResponseType.forbidden);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(inviteRepositoryProvider);

      expect(
        () => repo.sendInvite(
          inviteType: 'MANAGER',
          nurseryId: kTestNurseryId,
          targetMobile: '9200000000',
        ),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('500 Server error → ServerError', () async {
      fake.enqueue(type: FakeResponseType.serverError);
      final container = makeTestContainer(fake.apiClient);
      final repo = container.read(inviteRepositoryProvider);

      expect(
        () => repo.sendInvite(
          inviteType: 'MANAGER',
          nurseryId: kTestNurseryId,
          targetMobile: '9200000000',
        ),
        throwsA(isA<ServerError>()),
      );
    });

    test('provider override — no direct singleton call', () async {
      fake.enqueue(response: inviteResponse());
      final container = makeTestContainer(fake.apiClient);

      await container.read(inviteRepositoryProvider).sendInvite(
            inviteType: 'MANAGER',
            nurseryId: kTestNurseryId,
            targetMobile: '9200000000',
          );

      // Call was routed through the fake, not the real singleton
      expect(fake.calls, hasLength(1));
      expect(fake.calls.first.type, FakeResponseType.success);
    });
  });
}
