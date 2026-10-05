import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'visitor_feature_host.dart';

LaooWorkspaceUiTokens visitorOcrTokens(BuildContext context) {
  final values = visitorUiTokens;
  final theme = Theme.of(context);
  final input = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontSize: values.floatingLabelSource * .75,
  );
  return LaooWorkspaceUiTokens(
    contentMargin: EdgeInsets.all(values.cardMargin),
    cardPadding: EdgeInsets.all(values.cardPadding),
    sectionSpacing: values.cardSpacing,
    captionFilterSpacing: values.listSectionSpacing,
    itemSpacing: values.listItemSpacing,
    radius: values.radius,
    compactBreakpoint: 900,
    paginationHeight: values.paginationCardHeight,
    captionStyle: values.captionStyle,
    sectionStyle: theme.textTheme.titleMedium ?? input,
    inputStyle: input,
    tableStyle: input,
    buttonStyle: TextStyle(
      fontSize: values.buttonFontSize,
      fontWeight: FontWeight.w700,
    ),
    buttonHeight: values.buttonHeight,
    primaryColor: theme.colorScheme.primary,
    borderColor: theme.colorScheme.outlineVariant,
    backgroundColor: theme.scaffoldBackgroundColor,
  );
}
