import 'package:flutter/material.dart';

abstract final class LaooColors {
  static const white = Color(0xFFFFFFFF);

  /// Shared background for every application screen.
  static const background = Color(0xFFF8F9FB);
  static const pageCaption = Color(0xFF000000);
  static const surfaceSoft = Color(0xFFF7FAF8);
  static const textPrimary = Color(0xFF17221A);
  static const textSecondary = Color(0xFF66746A);
  static const border = Color(0xFFE4EAE6);

  static const green = Color(0xFF168364);
  static const greenDark = Color(0xFF0B4B3B);
  static const greenLight = Color(0xFFE8F7EF);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const pink = Color(0xFFFF4DA6);
  static const orange = Color(0xFFF97316);
  static const gold = Color(0xFFD4A017);
  static const brown = Color(0xFF795548);
  static const gray = Color(0xFF6B7280);
  static const teal = Color(0xFF0F9D8A);
  static const dark = Color(0xFF263238);
  static const success = Color(0xFF1F9D55);
  static const error = Color(0xFFD94A4A);
}

/// Shared spacing and Card layout values for application screens.
abstract final class LaooLayout {
  static const double cardSpacing = 10;
  static const double cardMargin = 10;
  static const double cardPadding = 10;
  static const double captionCardPaddingVertical = 12;
  static const double dialogInsetPadding = 24;
  static const double paginationCardHeight = 40;
}

abstract final class LaooRadius {
  static const xs = 4.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

abstract final class LaooShadows {
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x10000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Shared DataTable sizing and interaction values.
abstract final class LaooDataTable {
  /// Keeps the sequence ID compact and consistent across every list screen.
  static const TableColumnWidth idColumnWidth = FixedColumnWidth(48);
  static const double horizontalMargin = 12;
  static const double columnSpacing = 24;
  static const double dividerThickness = 1;

  /// Uses the active user-style primary color for row interaction feedback.
  static WidgetStateProperty<Color?> rowColor(Color primary) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return primary.withValues(alpha: 0.14);
      }
      if (states.contains(WidgetState.pressed)) {
        return primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered)) {
        return primary.withValues(alpha: 0.08);
      }
      return null;
    });
  }
}
