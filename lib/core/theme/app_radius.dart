import 'package:flutter/material.dart';

abstract class AppRadius {
  static const double xs  = 4;
  static const double sm  = 6;
  static const double md  = 8;
  static const double lg  = 10;
  static const double xl  = 12;
  static const double x2l = 16;
  static const double pill = 9999;

  static const BorderRadius cardRadius   = BorderRadius.all(Radius.circular(xl));
  // Primary buttons want a softer, more modern pill-leaning corner than the
  // rest of the UI's controls -- lg (10) read as a conservative, "flat"
  // rectangle at the 52px button height. x2l (16) sits in the 16-20px range
  // that reads as a deliberate primary action on iOS/Android alike.
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(x2l));
  static const BorderRadius inputRadius  = BorderRadius.all(Radius.circular(md));
  static const BorderRadius badgeRadius  = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius chipRadius   = BorderRadius.all(Radius.circular(x2l));
  static const BorderRadius sheetRadius  = BorderRadius.vertical(top: Radius.circular(x2l));
}
