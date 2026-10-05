import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';

LaooWorkspaceUiTokens businessCardOcrUi(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return LaooWorkspaceUiTokens(
    contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
    cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
    sectionSpacing: LaooLayout.listSectionSpacing,
    captionFilterSpacing: LaooLayout.listSectionSpacing,
    itemSpacing: LaooLayout.listItemSpacing,
    radius: LaooRadius.xs,
    compactBreakpoint: 900,
    paginationHeight: LaooLayout.paginationCardHeight,
    captionStyle: LaooTypography.screenCaptionStyle,
    sectionStyle: const TextStyle(
      fontSize: LaooTypography.sectionTitle,
      fontWeight: FontWeight.w700,
    ),
    inputStyle: const TextStyle(fontSize: LaooTypography.inputText),
    tableStyle: const TextStyle(fontSize: LaooTypography.tableBody),
    buttonStyle: const TextStyle(
      fontSize: LaooTypography.button,
      fontWeight: FontWeight.w700,
    ),
    buttonHeight: LaooTypography.buttonHeight,
    primaryColor: colors.primary,
    borderColor: LaooColors.border,
    backgroundColor: LaooColors.background,
  );
}

InputDecoration ocrInput(BuildContext context, String label, {IconData? icon}) {
  final t = businessCardOcrUi(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.radius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    border: border(t.borderColor),
    enabledBorder: border(t.borderColor),
    disabledBorder: border(t.borderColor),
    focusedBorder: border(t.primaryColor),
    errorBorder: border(Theme.of(context).colorScheme.error),
    focusedErrorBorder: border(Theme.of(context).colorScheme.error),
    labelStyle: t.inputStyle,
    floatingLabelStyle: t.inputStyle.copyWith(
      fontSize: (t.inputStyle.fontSize ?? 14) / .75,
    ),
  );
}
