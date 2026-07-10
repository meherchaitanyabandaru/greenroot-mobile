import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';

/// Creates a [ProviderContainer] with [apiClientProvider] overridden by
/// [fakeClient] and registers auto-dispose via [addTearDown].
///
/// ```dart
/// late FakeApiClient fake;
/// late ProviderContainer container;
///
/// setUp(() {
///   fake = FakeApiClient();
///   container = makeTestContainer(fake.apiClient);
/// });
/// ```
ProviderContainer makeTestContainer(
  ApiClient fakeClient, {
  List<Override> extraOverrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(fakeClient),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}
