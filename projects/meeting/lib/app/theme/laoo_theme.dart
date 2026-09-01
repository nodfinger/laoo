import 'package:flutter/material.dart';

import 'laoo_design_tokens.dart';
import 'laoo_typography.dart';

enum LaooThemeKey {
  green,
  blue,
  purple,
  pink,
  orange,
  gold,
  brown,
  gray,
  teal,
  dark,
}

abstract final class LaooTheme {
  static Color seedColor(LaooThemeKey key) {
    return switch (key) {
      LaooThemeKey.green => LaooColors.green,
      LaooThemeKey.blue => LaooColors.blue,
      LaooThemeKey.purple => LaooColors.purple,
      LaooThemeKey.pink => LaooColors.pink,
      LaooThemeKey.orange => LaooColors.orange,
      LaooThemeKey.gold => LaooColors.gold,
      LaooThemeKey.brown => LaooColors.brown,
      LaooThemeKey.gray => LaooColors.gray,
      LaooThemeKey.teal => LaooColors.teal,
      LaooThemeKey.dark => LaooColors.dark,
    };
  }

  static ThemeData fromKey(LaooThemeKey key) {
    final seed = seedColor(key);
    final darkMode = key == LaooThemeKey.dark;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: darkMode ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: LaooColors.background,
    );

    return base.copyWith(
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: base.colorScheme.primary,
        linearTrackColor: base.colorScheme.primary.withValues(alpha: 0.14),
        circularTrackColor: base.colorScheme.primary.withValues(alpha: 0.14),
      ),
      textTheme: LaooTypography.contentTextTheme(
        base.textTheme,
        textPrimary: darkMode ? Colors.white : LaooColors.textPrimary,
        textSecondary: darkMode ? Colors.white70 : LaooColors.textSecondary,
      ),
      primaryTextTheme: LaooTypography.contentTextTheme(base.primaryTextTheme),
      dataTableTheme: DataTableThemeData(
        dataRowColor: LaooDataTable.rowColor(seed),
        horizontalMargin: LaooDataTable.horizontalMargin,
        columnSpacing: LaooDataTable.columnSpacing,
        dividerThickness: LaooDataTable.dividerThickness,
        headingTextStyle: TextStyle(
          fontSize: LaooTypography.tableHeader,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: const TextStyle(fontSize: LaooTypography.tableBody),
      ),
      cardTheme: CardThemeData(
        color: darkMode ? const Color(0xFF1B2422) : Colors.white,
        elevation: 0,
        margin: const EdgeInsets.all(LaooLayout.cardMargin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.lg),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LaooColors.background,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
        titleTextStyle: LaooTypography.popupTitleStyle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.lg),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
