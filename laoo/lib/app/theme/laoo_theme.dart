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
  static Color seedColor(LaooThemeKey key) => switch (key) {
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

  static ThemeData fromKey(LaooThemeKey key) {
    final darkMode = key == LaooThemeKey.dark;
    final seed = seedColor(key);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: darkMode ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: darkMode
          ? const Color(0xFF111716)
          : Colors.white,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.lg),
          side: BorderSide(
            color: darkMode ? Colors.white12 : LaooColors.border,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMode ? const Color(0xFF1B2422) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.md),
          borderSide: const BorderSide(color: LaooColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.md),
          borderSide: BorderSide(color: seed, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.sm),
          ),
        ),
      ),
    );
  }
}
