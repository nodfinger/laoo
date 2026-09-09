import 'package:flutter/material.dart';

import 'app_theme_key.dart';
import 'laoo_design_tokens.dart';
import 'laoo_typography.dart';

abstract final class AppTheme {
  static ThemeData fromKey(AppThemeKey key) {
    return switch (key) {
      AppThemeKey.green => _build(seedColor: const Color(0xFF1ABC9C)),
      AppThemeKey.blue => _build(seedColor: const Color(0xFF1976D2)),
    };
  }

  static ThemeData _build({required Color seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: BorderSide.none,
        ),
        titleTextStyle: const TextStyle(
          fontFamily: LaooTypography.fontFamily,
          fontFamilyFallback: LaooTypography.fontFallback,
          fontSize: LaooTypography.workspaceCaption,
          height: LaooTypography.titleLineHeight,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(120, LaooTypography.buttonHeight),
          maximumSize: const Size(double.infinity, LaooTypography.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
