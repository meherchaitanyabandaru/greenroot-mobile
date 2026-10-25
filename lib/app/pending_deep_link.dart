/// The link that opened the app before the session was ready (an invite,
/// an order from a notification). The router stores it while it sends the
/// user to splash or sign-in; once signed in, the user lands there instead
/// of on home. Route guards still apply to it as usual.
class PendingDeepLink {
  PendingDeepLink._();

  static String? _location;

  static const _notRemembered = {'/', '/login', '/otp', '/home'};

  static void remember(Uri uri) {
    if (_notRemembered.contains(uri.path)) return;
    _location = uri.toString();
  }

  /// Returns the stored link once, then forgets it.
  static String? take() {
    final location = _location;
    _location = null;
    return location;
  }
}
