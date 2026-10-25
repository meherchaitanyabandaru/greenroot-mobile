import 'package:flutter/widgets.dart';

/// Counts the dialogs and bottom sheets open on the app's navigator, so the
/// Ask Mango button can step aside while one is shown (it would sit on the
/// sheet's own buttons and fields).
class MangoPopupObserver extends NavigatorObserver {
  /// How many popups (dialogs, bottom sheets, menus) are open now.
  final ValueNotifier<int> open = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) open.value++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _closed(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _closed(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _closed(oldRoute);
    if (newRoute is PopupRoute) open.value++;
  }

  void _closed(Route<dynamic> route) {
    if (route is PopupRoute && open.value > 0) open.value--;
  }
}

/// The app's one observer, registered on the router.
final mangoPopups = MangoPopupObserver();
