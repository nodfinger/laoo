import 'package:flutter/material.dart';

/// Central typography tokens for Laoo Solutions.
///
/// Feature code should reference these tokens instead of hard-coding fontSize.
/// Font family and ThemeData integration are applied separately by the
/// application's central theme layer.
abstract final class LaooTypography {
  // Font system
  /// Bundled font family declared in pubspec.yaml.
  static const String fontFamily = 'NotoSansThai';
  static const List<String> fontFallback = <String>[
    'Noto Sans Thai',
    'Tahoma',
    'Arial',
    'sans-serif',
  ];

  // Page hierarchy
  static const double pageTitle = 18;
  static const double workspaceCaption = 18;
  static const double sectionTitle = 16;
  static const double subsectionTitle = 14;

  // General text
  static const double body = 13;
  static const double bodySmall = 12;
  static const double caption = 11;

  // Form / input
  static const double inputText = 13;
  static const double inputLabel = 16;
  static const double inputHint = 12;
  static const double validation = 12;
  static const double comboBox = 12;

  // Table
  static const double tableHeader = 13;
  static const double tableBody = 13;

  // Buttons / menus
  static const double button = 13;

  /// Shared button height keeps icon and text buttons visually aligned.
  static const double buttonHeight = 48;
  static const double menuGroup = 14;
  static const double menuItem = 12;
  static const double popupMenu = 12;

  // User / shell
  static const double userName = 13;
  static const double userContext = 10;
  static const double systemTitle = 13.5;
  static const double systemVersion = 8.5;

  // Thai readability
  static const double titleLineHeight = 1.3;
  static const double bodyLineHeight = 1.5;
  static const double inputLineHeight = 1.45;

  // Weight standards
  static const FontWeight pageTitleWeight = FontWeight.w700;
  static const FontWeight workspaceCaptionWeight = FontWeight.w700;
  static const FontWeight strongWeight = FontWeight.w800;
  static const FontWeight emphasizedWeight = FontWeight.w700;
  static const FontWeight normalWeight = FontWeight.w400;
}
