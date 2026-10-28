import 'package:intl/intl.dart';

/// A timeline step's time in local time, e.g. "Wed, 28 Oct · 10:19 AM"; '' if none.
String stepTime(String? iso) {
  final dt = iso == null ? null : DateTime.tryParse(iso);
  return dt == null ? '' : DateFormat('EEE, d MMM · h:mm a').format(dt.toLocal());
}
