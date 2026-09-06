import 'package:flutter/material.dart';

import 'laoo_design_tokens.dart';

/// Central typography standard for LAOO.
///
/// Feature code should reference these tokens instead of hard-coding fontSize.
/// Font family and ThemeData integration are applied separately by the
/// application's central theme layer.
abstract final class LaooTypography {
  // Font system standard: NotoSansThai with the approved fallbacks only.
  /// Bundled font family declared in pubspec.yaml.
  static const String fontFamily = 'NotoSansThai';
  static const List<String> fontFallback = <String>[
    'Noto Sans Thai',
    'Tahoma',
    'Arial',
  ];

  // Page hierarchy
  static const double pageTitle = 18;
  static const double workspaceCaption = 18;
  static const double sectionTitle = 16;
  static const double subsectionTitle = 14;

  // General text
  static const double body = 14;
  static const double bodySmall = 14;
  static const double caption = 11;

  // Form / input standard: TextBox and ComboBox 14px, Label 16px.
  static const double inputText = 14;
  static const double inputLabel = 16;
  static const double inputHint = 12;
  static const double validation = 12;
  static const double comboBox = 14;

  // Table
  static const double tableHeader = 14;
  static const double tableBody = 14;

  // Button standard: 14px.
  static const double button = 14;

  /// Shared button height keeps icon and text buttons visually aligned.
  static const double buttonHeight = 48;
  static const double menuGroup = 14;
  static const double menuItem = 13;
  static const double popupMenu = 12;

  // User / shell
  static const double userName = 13;
  static const double userContext = 10;
  static const double systemTitle = 13.5;
  static const double systemVersion = 8.5;
  static const double mobileSystemTitle = 17;
  static const double mobileSystemVersion = 11;

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

  /// Top caption shared by List, Card, Action and Popup screens.
  static const TextStyle pageCaptionStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: workspaceCaption,
    height: titleLineHeight,
    fontWeight: workspaceCaptionWeight,
    color: LaooColors.pageCaption,
  );

  static const TextStyle popupTitleStyle = pageCaptionStyle;

  static TextTheme contentTextTheme(
    TextTheme base, {
    Color? textPrimary,
    Color? textSecondary,
  }) {
    final themed = base.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    return themed.copyWith(
      bodyLarge: themed.bodyLarge?.copyWith(
        fontSize: body,
        height: bodyLineHeight,
        color: textPrimary,
      ),
      bodyMedium: themed.bodyMedium?.copyWith(
        fontSize: body,
        height: bodyLineHeight,
        color: textPrimary,
      ),
      bodySmall: themed.bodySmall?.copyWith(
        fontSize: bodySmall,
        height: bodyLineHeight,
        color: textSecondary ?? textPrimary,
      ),
      titleMedium: themed.titleMedium?.copyWith(
        fontSize: inputText,
        height: inputLineHeight,
        color: textPrimary,
      ),
      labelLarge: themed.labelLarge?.copyWith(
        fontSize: button,
        height: bodyLineHeight,
      ),
      labelMedium: themed.labelMedium?.copyWith(
        fontSize: inputLabel,
        height: bodyLineHeight,
      ),
    );
  }
}
