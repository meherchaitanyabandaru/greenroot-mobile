import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/widgets/profile_completion_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  int ago(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;

  test('never shown: not snoozed', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await completionPromptSnoozed(), isFalse);
  });

  test('shown yesterday: snoozed; shown 4 days ago: shows again', () async {
    SharedPreferences.setMockInitialValues(
        {'profile_prompt_shown_at': ago(const Duration(days: 1))},);
    expect(await completionPromptSnoozed(), isTrue);
    SharedPreferences.setMockInitialValues(
        {'profile_prompt_shown_at': ago(const Duration(days: 4))},);
    expect(await completionPromptSnoozed(), isFalse);
  });
}
