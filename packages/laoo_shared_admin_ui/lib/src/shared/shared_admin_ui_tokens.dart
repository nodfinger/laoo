import 'package:flutter/material.dart';

typedef SharedAdminErrorText = String Function(Object error);
typedef SharedAdminTitleBuilder =
    Widget Function(BuildContext context, String title, bool showFavorite);
typedef SharedAdminMessageBuilder =
    Widget Function(
      BuildContext context,
      String message,
      bool error,
      VoidCallback onClose,
    );

class SharedAdminUiTokens {
  const SharedAdminUiTokens({
    required this.contentMargin,
    required this.cardPadding,
    required this.cardSpacing,
    required this.itemSpacing,
    required this.radius,
    required this.compactBreakpoint,
    required this.paginationHeight,
    required this.captionStyle,
    this.filterActionHeight = 48,
    this.listViewToggleSize = 40,
    this.paginationButtonSize = 36,
    this.fieldSpacing = 14,
    this.inputLabelStyle,
    this.floatingLabelStyle,
    this.sectionTitleStyle,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double cardSpacing;
  final double itemSpacing;
  final double radius;
  final double compactBreakpoint;
  final double paginationHeight;
  final TextStyle captionStyle;
  final double filterActionHeight;
  final double listViewToggleSize;
  final double paginationButtonSize;
  final double fieldSpacing;
  final TextStyle? inputLabelStyle;
  final TextStyle? floatingLabelStyle;
  final TextStyle? sectionTitleStyle;
}
