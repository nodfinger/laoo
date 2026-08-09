import 'package:flutter/material.dart';

/// Central typography tokens for Laoo Solutions.
///
/// Feature code should reference these tokens instead of hard-coding fontSize.
/// Font family and ThemeData integration are applied separately by the
/// application's central theme layer.
abstract final class LaooTypography {
  // Page hierarchy
  static const double pageTitle = 28;
  static const double sectionTitle = 16;
  static const double subsectionTitle = 14;

  // General text
  static const double body = 12;
  static const double bodySmall = 11;
  static const double caption = 10;

  // Form / input
  static const double inputText = 13;
  static const double inputLabel = 16;
  static const double inputHint = 11;
  static const double validation = 11;

  // Table
  static const double tableHeader = 12;
  static const double tableBody = 12;

  // Buttons / menus
  static const double button = 12;
  static const double menuGroup = 14;
  static const double menuItem = 12;
  static const double popupMenu = 12;

  // User / shell
  static const double userName = 13;
  static const double userContext = 10;
  static const double systemTitle = 13.5;
  static const double systemVersion = 8.5;

  // Weight standards
  static const FontWeight pageTitleWeight = FontWeight.w900;
  static const FontWeight strongWeight = FontWeight.w800;
  static const FontWeight emphasizedWeight = FontWeight.w700;
  static const FontWeight normalWeight = FontWeight.w400;
}
