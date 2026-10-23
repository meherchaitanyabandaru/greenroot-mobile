import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/utilities/text_case.dart';

void main() {
  test('all-lowercase names are title-cased, spaces tidied', () {
    expect(tidyName('kavitha  reddy '), 'Kavitha Reddy');
    expect(tidyName('sri lakshmi nursery'), 'Sri Lakshmi Nursery');
    expect(tidyName('main road, kadiyam'), 'Main Road, Kadiyam');
  });
  test('text typed with capitals is kept', () {
    expect(tidyName('ABC Nursery'), 'ABC Nursery');
    expect(tidyName('McNeil'), 'McNeil');
  });
}
