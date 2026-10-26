// A driver joins a trip with its QR code (TRIP-<trip_uuid>), never the
// sequential dispatch code, which anyone could guess.
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/dispatches/dispatches.dart';

void main() {
  Map<String, dynamic> json({String? uuid}) => {
        'id': 7,
        'dispatch_code': 'DSP-20261026-0007',
        'order_id': 9,
        'dispatch_status': 'PENDING',
        'created_at': '2026-10-26T10:00:00Z',
        if (uuid != null) 'trip_uuid': uuid,
      };

  test('the trip code is built from trip_uuid', () {
    final d = Dispatch.fromJson(json(uuid: 'e0862511-0336-4e26-9e2b-be3da1d1b6ae'));
    expect(d.tripCode, 'TRIP-e0862511-0336-4e26-9e2b-be3da1d1b6ae');
  });

  test('no trip_uuid, no code: never falls back to the dispatch code', () {
    expect(Dispatch.fromJson(json()).tripCode, isNull);
  });
}
