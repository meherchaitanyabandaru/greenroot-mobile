import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_radius.dart';

const _red950 = Color(0xFF450a0a);

abstract class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark  => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark ? _darkScheme : _lightScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.background,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: AppTypography.h3.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        shadowColor: AppColors.slate200.withValues(alpha: 0.5),
      ),

      // ── Elevated Button ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMain,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          elevation: 0,
          textStyle: AppTypography.button,
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryMain,
          side: const BorderSide(color: AppColors.primaryMain, width: 1.5),
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          textStyle: AppTypography.button,
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryMain,
          textStyle: AppTypography.button,
        ),
      ),

      // ── Input Decoration ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.primaryMain, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.red500),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.red500, width: 1.5),
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
        labelStyle: AppTypography.label.copyWith(color: AppColors.textSecondary),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.red600),
      ),

      // ── Card ─────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.sm,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),

      // ── Bottom Nav ───────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        selectedItemColor: AppColors.primaryMain,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primaryMain,
        ),
        unselectedLabelStyle: AppTypography.caption,
        elevation: 0,
      ),

      // ── Chip ─────────────────────────────────────────────────────────────────
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.forest100,
        selectedColor: AppColors.primaryMain,
        labelStyle: AppTypography.label,
        side: BorderSide.none,
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // ── Text ─────────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge:   AppTypography.displayLarge,
        headlineLarge:  AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall:  AppTypography.h3,
        titleLarge:     AppTypography.h3,
        titleMedium:    AppTypography.h4,
        titleSmall:     AppTypography.label,
        bodyLarge:      AppTypography.bodyLarge,
        bodyMedium:     AppTypography.body,
        bodySmall:      AppTypography.bodySmall,
        labelLarge:     AppTypography.label,
        labelMedium:    AppTypography.caption,
        labelSmall:     AppTypography.overline,
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────────
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
    );
  }

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primaryMain,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.forest900,
    secondary: AppColors.accentMain,
    onSecondary: AppColors.forest950,
    secondaryContainer: AppColors.accentLight,
    onSecondaryContainer: AppColors.forest900,
    error: AppColors.red600,
    onError: Colors.white,
    errorContainer: AppColors.red100,
    onErrorContainer: AppColors.red700,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.slate100,
    outline: AppColors.border,
    outlineVariant: AppColors.borderStrong,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.forest500,
    onPrimary: AppColors.forest950,
    primaryContainer: AppColors.forest800,
    onPrimaryContainer: AppColors.forest100,
    secondary: AppColors.lime400,
    onSecondary: AppColors.forest950,
    secondaryContainer: AppColors.forest800,
    onSecondaryContainer: AppColors.lime100,
    error: AppColors.red500,
    onError: _red950,
    errorContainer: AppColors.red700,
    onErrorContainer: AppColors.red100,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    surfaceContainerHighest: Color(0xFF1a2520),
    outline: AppColors.darkBorder,
    outlineVariant: Color(0xFF2a3d30),
  );
}
