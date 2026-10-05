import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../app/theme/laoo_design_tokens.dart';
import '../../app/theme/laoo_typography.dart';

LaooWorkspaceUiTokens businessCardOcrTokens(BuildContext context) =>
    LaooWorkspaceUiTokens(
      contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
      cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
      sectionSpacing: LaooLayout.cardSpacing,
      captionFilterSpacing: LaooLayout.listSectionSpacing,
      itemSpacing: LaooLayout.listItemSpacing,
      radius: LaooRadius.xs,
      compactBreakpoint: 900,
      paginationHeight: LaooLayout.paginationCardHeight,
      captionStyle: LaooTypography.screenCaptionStyle,
      sectionStyle: const TextStyle(
        fontSize: LaooTypography.sectionTitle,
        fontWeight: FontWeight.w600,
      ),
      inputStyle: const TextStyle(fontSize: LaooTypography.inputText),
      tableStyle: const TextStyle(fontSize: LaooTypography.tableBody),
      buttonStyle: const TextStyle(
        fontSize: LaooTypography.button,
        fontWeight: FontWeight.w700,
      ),
      buttonHeight: LaooTypography.buttonHeight,
      primaryColor: Theme.of(context).colorScheme.primary,
      borderColor: LaooColors.border,
      backgroundColor: LaooColors.background,
    );
