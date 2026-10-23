/// "kavitha  reddy" → "Kavitha Reddy". Only all-lowercase text is changed, so
/// something typed with care ("McNeil", "ABC Nursery", "D'Souza") is kept.
/// For names and places people type on a phone without capitals.
String tidyName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name != name.toLowerCase()) return name;
  return name
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
