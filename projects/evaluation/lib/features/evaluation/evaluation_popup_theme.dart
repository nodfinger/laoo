import 'package:flutter/material.dart';

import 'evaluation_feature_host.dart';

/// Keeps Evaluation dialogs white and their text legible for every user style.
ThemeData evaluationPopupTheme(BuildContext context) {
  final theme = Theme.of(context);
  final tokens = evaluationUiTokens;
  final radius = BorderRadius.circular(tokens.radius);
  OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  return theme.copyWith(
    dividerColor: tokens.borderColor,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, tokens.buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: tokens.buttonStyle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, tokens.buttonHeight),
        foregroundColor: tokens.primaryColor,
        side: BorderSide(color: tokens.primaryColor),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: tokens.buttonStyle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: tokens.buttonStyle,
      ),
    ),
    colorScheme: theme.colorScheme.copyWith(
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black54,
    ),
    textTheme: theme.textTheme.apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
    ),
    cardTheme: theme.cardTheme.copyWith(
      color: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      border: fieldBorder(tokens.borderColor),
      enabledBorder: fieldBorder(tokens.borderColor),
      disabledBorder: fieldBorder(tokens.borderColor),
      focusedBorder: fieldBorder(tokens.primaryColor, width: 1.5),
      errorBorder: fieldBorder(tokens.dangerColor),
      focusedErrorBorder: fieldBorder(tokens.dangerColor, width: 1.5),
      floatingLabelStyle: tokens.inputStyle.copyWith(
        color: tokens.primaryColor,
        fontSize: 14 / .75,
      ),
    ),
  );
}
