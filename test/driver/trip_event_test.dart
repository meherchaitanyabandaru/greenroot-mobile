import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';

import '../helpers/fake_api_client.dart';

void main() {
  // The API replies {"event": {...}} and reads the note from `remarks`. The app
  // used to parse the wrapper (an error after a successful save, so drivers
  // re-sent the event) and send `note` (dropped).
  test('addTripEvent sends remarks and parses the API reply', () async {
    final fake = FakeApiClient();
    fake.enqueue(response: {
      'event': {
        'id': 7,
        'dispatch_id': 60,
        'event_type': 'DELAY',
        'remarks': 'Traffic jam',
        'created_by_user_id': 1835,
        'created_at': '2026-10-21T16:40:43Z',
      },
    },);

    final event = await DispatchRepository(fake.apiClient)
        .addTripEvent(60, 'DELAY', note: 'Traffic jam');

    expect(event.id, 7);
    expect(event.note, 'Traffic jam');
    final body = fake.calls.single.data as Map;
    expect(body['remarks'], 'Traffic jam');
    expect(body.containsKey('note'), isFalse);
  });
}
