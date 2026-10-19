import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema centralizado do Firewatch (tema claro e escuro, Material 3).
abstract final class AppTheme {
  static ThemeData get light => _buildLight();
  static ThemeData get dark => _buildDark();

  static TextTheme _text(ColorScheme scheme) {
    return GoogleFontsLike.interTextTheme(scheme);
  }

  static ColorScheme _colorScheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: AppColors.orange,
      onPrimary: AppColors.charcoal,
      secondary: AppColors.orangeText,
      onSecondary: AppColors.white,
      error: AppColors.riskCritical,
      onError: AppColors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.white,
      onSurface: isDark ? AppColors.white : AppColors.charcoal,
      onSurfaceVariant: isDark ? AppColors.grayLight : AppColors.grayDark,
      outline: isDark ? AppColors.darkBorder : AppColors.border,
      outlineVariant: isDark ? AppColors.darkBorder : AppColors.border,
      surfaceContainerHighest: isDark
          ? AppColors.darkSurfaceHigh
          : AppColors.border,
      inverseSurface: isDark ? AppColors.background : AppColors.charcoal,
      onInverseSurface: isDark ? AppColors.charcoal : AppColors.white,
      inversePrimary: AppColors.amber,
      shadow: isDark ? Colors.black : AppColors.charcoal,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _buildLight() {
    final scheme = _colorScheme(brightness: Brightness.light);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    return _applyCommon(base, scheme);
  }

  static ThemeData _buildDark() {
    final scheme = _colorScheme(brightness: Brightness.dark);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
    return _applyCommon(base, scheme);
  }

  static ThemeData _applyCommon(ThemeData base, ColorScheme scheme) {
    final isDark = base.brightness == Brightness.dark;
    final borderColor = scheme.outline;

    return base.copyWith(
      textTheme: _text(scheme),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        contentTextStyle: AppTypography.inter(AppColors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: AppTypography.inter(scheme.onSurfaceVariant, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.charcoal,
          minimumSize: const Size(48, 48),
          disabledBackgroundColor: AppColors.grayLight.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.inter(
            AppColors.charcoal,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.inter(
            scheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.amber : AppColors.orangeText,
          textStyle: AppTypography.inter(
            isDark ? AppColors.amber : AppColors.orangeText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: AppColors.orange,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: AppTypography.inter(
          scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.orange;
          return borderColor;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.orange.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.inter(
            states.contains(WidgetState.selected)
                ? AppColors.orangeText
                : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.orangeDark
                : scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.orange,
        linearTrackColor: borderColor,
      ),
    );
  }
}

/// Ponte para usar as fontes do Google via [AppTypography] no [TextTheme].
abstract final class GoogleFontsLike {
  static TextTheme interTextTheme(ColorScheme scheme) {
    final w = scheme.onSurface; // warm title color
    final b = scheme.onSurfaceVariant;
    return TextTheme(
      displayLarge: AppTypography.sora(
        w,
        fontSize: 57,
        height: 1.12,
        letterSpacing: -1,
      ),
      displayMedium: AppTypography.sora(
        w,
        fontSize: 45,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      displaySmall: AppTypography.sora(w, fontSize: 36, height: 1.2),
      headlineLarge: AppTypography.sora(
        w,
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: AppTypography.sora(
        w,
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: AppTypography.sora(
        w,
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: AppTypography.sora(
        w,
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: AppTypography.inter(
        w,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: AppTypography.inter(
        w,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: AppTypography.inter(b, fontSize: 16, height: 1.5),
      bodyMedium: AppTypography.inter(b, fontSize: 14, height: 1.5),
      bodySmall: AppTypography.inter(b, fontSize: 12, height: 1.45),
      labelLarge: AppTypography.inter(
        w,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: AppTypography.inter(
        b,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: AppTypography.inter(
        b,
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
