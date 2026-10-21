import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/utilities/number_input.dart';

String _type(List<TextInputFormatter> rules, String from, String to) {
  var value = TextEditingValue(
      text: from, selection: TextSelection.collapsed(offset: from.length),);
  final next = TextEditingValue(
      text: to, selection: TextSelection.collapsed(offset: to.length),);
  for (final r in rules) {
    value = r.formatEditUpdate(value, next);
  }
  return value.text;
}

void main() {
  test('money keeps a valid amount and refuses a second dot or a third decimal',
      () {
    expect(_type(NumberInput.money, '40', '40.5'), '40.5');
    expect(_type(NumberInput.money, '40.', '40..'), '40.');
    expect(_type(NumberInput.money, '40.55', '40.555'), '40.55');
    expect(_type(NumberInput.money, '', 'abc'), '');
  });

  test('whole numbers only', () {
    expect(_type(NumberInput.whole, '10', '10.5'), '105');
    expect(_type(NumberInput.whole, '', '1,000'), '1000');
  });
}
