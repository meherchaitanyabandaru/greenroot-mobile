import 'package:intl/intl.dart';

final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Rupees with Indian grouping: inr(100120) == "₹1,00,120.00".
/// [paise] false rounds to whole rupees ("₹4,500"), for running line totals.
String inr(num amount, {bool paise = true}) =>
    (paise ? _inr2 : _inr0).format(amount);
