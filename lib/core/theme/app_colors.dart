import 'package:flutter/material.dart';

/// GreenRoot design tokens — mirrors the admin UI palette exactly.
/// Primary: Forest Green, Accent: Lime, Neutrals: Slate.
abstract class AppColors {
  // ── Forest Green (brand primary) ──────────────────────────────────────────
  static const forest950 = Color(0xFF052e16);
  static const forest900 = Color(0xFF14532d);
  static const forest800 = Color(0xFF166534); // primary main
  static const forest700 = Color(0xFF15803d);
  static const forest600 = Color(0xFF16a34a); // success / primaryMid
  static const forest500 = Color(0xFF22c55e);
  static const forest400 = Color(0xFF4ade80);
  static const forest200 = Color(0xFFbbf7d0);
  static const forest100 = Color(0xFFdcfce7);
  static const forest50  = Color(0xFFf0fdf4);

  // ── Lime (accent) ──────────────────────────────────────────────────────────
  static const lime500 = Color(0xFF84cc16); // accent main
  static const lime400 = Color(0xFFa3e635);
  static const lime200 = Color(0xFFd9f99d);
  static const lime100 = Color(0xFFecfccb);
  static const lime50  = Color(0xFFf7fee7);

  // ── Slate (neutrals) ──────────────────────────────────────────────────────
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0f172a); // text primary
  static const slate800 = Color(0xFF1e293b);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748b); // text secondary
  static const slate400 = Color(0xFF94a3b8);
  static const slate300 = Color(0xFFcbd5e1);
  static const slate200 = Color(0xFFe2e8f0); // border
  static const slate100 = Color(0xFFf1f5f9);
  static const slate50  = Color(0xFFf8fafc); // background

  // ── Status ────────────────────────────────────────────────────────────────
  static const blue700 = Color(0xFF1d4ed8);
  static const blue600 = Color(0xFF2563eb);
  static const blue500 = Color(0xFF3b82f6);
  static const blue100 = Color(0xFFdbeafe);
  static const blue50  = Color(0xFFeff6ff);

  static const amber700 = Color(0xFFb45309);
  static const amber600 = Color(0xFFd97706);
  static const amber500 = Color(0xFFf59e0b);
  static const amber100 = Color(0xFFfef3c7);
  static const amber50  = Color(0xFFfffbeb);

  static const red700 = Color(0xFFb91c1c);
  static const red600 = Color(0xFFdc2626);
  static const red500 = Color(0xFFef4444);
  static const red100 = Color(0xFFfee2e2);
  static const red50  = Color(0xFFfef2f2);

  static const teal700 = Color(0xFF0f766e);
  static const teal500 = Color(0xFF14b8a6);
  static const teal100 = Color(0xFFccfbf1);

  static const purple700 = Color(0xFF6d28d9);
  static const purple500 = Color(0xFF8b5cf6);
  static const purple100 = Color(0xFFede9fe);

  static const orange700 = Color(0xFFc2410c);
  static const orange500 = Color(0xFFf97316);
  static const orange100 = Color(0xFFffedd5);

  // ── Semantic aliases ───────────────────────────────────────────────────────
  static const background    = slate50;
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceHover  = slate50;

  static const textPrimary   = slate900;
  static const textSecondary = slate500;
  static const textMuted     = slate400;
  static const textInverse   = Color(0xFFFFFFFF);

  static const border        = slate200;
  static const borderStrong  = slate300;
  static const borderFocus   = forest800;

  static const primaryMain   = forest800;
  static const primaryHover  = forest900;
  static const primaryLight  = forest100;
  static const primaryMid    = forest600;

  static const accentMain    = lime500;
  static const accentHover   = Color(0xFF65a30d);
  static const accentLight   = lime100;

  static const successText   = forest700;
  static const successBg     = forest100;
  static const warningText   = amber700;
  static const warningBg     = amber100;
  static const errorText     = red600;
  static const errorBg       = red100;
  static const infoText      = blue600;
  static const infoBg        = blue100;

  // ── Dark theme ────────────────────────────────────────────────────────────
  static const darkBackground  = Color(0xFF0a0f0c);
  static const darkSurface     = Color(0xFF111815);
  static const darkBorder      = Color(0xFF1e2d24);
  static const darkTextPrimary = Color(0xFFecfdf5);
}
