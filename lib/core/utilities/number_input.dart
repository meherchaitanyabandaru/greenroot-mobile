import 'package:flutter/services.dart';

/// Input rules for numeric text fields. Values are read with `tryParse`, so
/// without these a typo ("40..", "1,000") silently became null — e.g. an ad
/// posted as "price on request".
abstract final class NumberInput {
  /// Counts: quantities, capacities.
  static final whole = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];

  /// Rupee amounts: digits with at most one dot and two decimals.
  static final money = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ];
}
