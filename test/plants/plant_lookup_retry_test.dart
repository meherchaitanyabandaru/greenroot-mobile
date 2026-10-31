// Plant search is retried once when the connection drops or times out (seen
// once on Wi-Fi in Local Market "Plants I want"); a second failure is shown.
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/errors/app_error.dart';
import 'package:greenroot_mobile/features/plants/plants.dart';

import '../helpers/fake_api_client.dart';

void main() {
  test('a dropped search is tried once more, then answers', () async {
    final fake = FakeApiClient()..reset();
    fake.enqueue(type: FakeResponseType.networkError);
    fake.enqueue(response: {'results': [{'match_type': 'BOTANICAL', 'name': {'wfo_id': 'wfo-1', 'scientific_name': 'Mangifera indica'}}]});
    final found = await PlantRepository(fake.apiClient).lookupPlants('mango');
    expect(found.single.scientificName, 'Mangifera indica');
    expect(fake.calls.length, 2);
  });

  test('two failures in a row are reported (no endless retries)', () async {
    final fake = FakeApiClient()..reset();
    fake.enqueue(type: FakeResponseType.networkError);
    fake.enqueue(type: FakeResponseType.networkError);
    await expectLater(PlantRepository(fake.apiClient).lookupPlants('mango'), throwsA(isA<NetworkError>()));
    expect(fake.calls.length, 2);
  });

  test('a server error is not retried', () async {
    final fake = FakeApiClient()..reset();
    fake.enqueue(type: FakeResponseType.serverError);
    await expectLater(PlantRepository(fake.apiClient).lookupPlants('mango'), throwsA(isA<AppError>()));
    expect(fake.calls.length, 1);
  });
}
