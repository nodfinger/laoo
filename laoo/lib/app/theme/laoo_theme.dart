import 'package:flutter/material.dart';

import 'laoo_design_tokens.dart';

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
      scaffoldBackgroundColor: darkMode
          ? const Color(0xFF111716)
          : LaooColors.background,
    );

    const thaiFontFamily = 'Leelawadee UI';
    const thaiFallback = <String>[
      'Noto Sans Thai',
      'Tahoma',
      'Arial',
      'sans-serif',
    ];

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: thaiFontFamily,
        fontFamilyFallback: thaiFallback,
        bodyColor: darkMode ? Colors.white : LaooColors.textPrimary,
        displayColor: darkMode ? Colors.white : LaooColors.textPrimary,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: thaiFontFamily,
        fontFamilyFallback: thaiFallback,
      ),
      cardTheme: CardThemeData(
        color: darkMode ? const Color(0xFF1B2422) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.lg),
          side: BorderSide(
            color: darkMode
                ? Colors.white.withValues(alpha: 0.08)
                : LaooColors.border,
          ),
        ),
      ),
    );
  }
}
