import 'package:flutter/foundation.dart';

import 'mango_guides.dart';

/// State of Ask Mango: closed, choosing a guide, on a step, or finished.
class MangoController extends ChangeNotifier {
  MangoGuide? _guide;
  int _step = 0;
  bool _picking = false;
  bool _done = false;

  MangoGuide? get guide => _guide;
  int get stepIndex => _step;
  MangoStep? get step => _guide == null || _done ? null : _guide!.steps[_step];
  bool get picking => _picking;
  bool get done => _done;
  bool get active => _picking || _guide != null;
  bool get isFirst => _step == 0;
  bool get isLast => _guide != null && _step == _guide!.steps.length - 1;

  void openPicker() {
    _picking = true;
    _guide = null;
    _done = false;
    notifyListeners();
  }

  void start(MangoGuide g) {
    _guide = g;
    _step = 0;
    _picking = false;
    _done = false;
    notifyListeners();
  }

  void next() {
    if (_guide == null || _done) return;
    if (isLast) {
      _done = true;
    } else {
      _step++;
    }
    notifyListeners();
  }

  void back() {
    if (_guide == null) return;
    if (_done) {
      _done = false;
    } else if (_step > 0) {
      _step--;
    }
    notifyListeners();
  }

  void replay() {
    if (_guide != null) start(_guide!);
  }

  /// Exit at any time; nothing in the app is changed by the guide.
  void exit() {
    _guide = null;
    _picking = false;
    _done = false;
    _step = 0;
    notifyListeners();
  }
}

/// The app's single guide.
final mango = MangoController();
