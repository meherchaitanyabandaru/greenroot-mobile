import 'package:flutter/services.dart';

// One rule for Indian mobile numbers, matching the API (common/phone):
// 10 digits starting 6–9; "+91", "91" and a leading "0" are prefixes, not digits.

final _valid = RegExp(r'^[6-9]\d{9}$');

/// The 10-digit number inside [raw] ("+91 98765-43210" → "9876543210").
String normalizeIndianMobile(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
  if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
  return digits;
}

bool isValidIndianMobile(String raw) => _valid.hasMatch(normalizeIndianMobile(raw));

/// Form validator; [required] false lets an empty field pass.
String? validateIndianMobile(String? value, {bool required = true}) {
  final v = normalizeIndianMobile(value ?? '');
  if (v.isEmpty) return required ? 'Mobile number is required' : null;
  return _valid.hasMatch(v) ? null : 'Enter a 10-digit mobile number starting with 6, 7, 8 or 9';
}

/// Keeps the field at the 10 real digits, also when a formatted number such
/// as "+91 98765 43210" is pasted (plain digit filters would keep "9198765432").
class IndianMobileInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = normalizeIndianMobile(newValue.text);
    if (digits.length > 10) digits = digits.substring(0, 10);
    return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
  }
}
