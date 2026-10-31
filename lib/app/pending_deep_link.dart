/// The link that opened the app before the session was ready (an invite,
/// an order from a notification). The router stores it while it sends the
/// user to splash or sign-in; once signed in, the user lands there instead
/// of on home. Route guards still apply to it as usual.
class PendingDeepLink {
  PendingDeepLink._();

  static String? _location;

  // The suspended page too: signing out from it must not bring the next
  // sign-in back to it after the account is reactivated.
  static const _notRemembered = {'/', '/login', '/otp', '/home', '/account-suspended'};

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
