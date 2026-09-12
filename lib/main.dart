import 'package:flutter/material.dart';
import 'package:laoo_meeting/meeting_feature.dart';
import 'package:laoo_service/service_feature.dart';
import 'package:laoo_time/time_feature.dart';
import 'package:laoo_visitor/visitor_feature.dart';

import 'app/laoo_app.dart';
import 'app/theme/laoo_design_tokens.dart';
import 'app/theme/laoo_typography.dart';
import 'core/api/api_client.dart';
import 'core/api/api_exception.dart';
import 'core/company_setup/company_setup_controller.dart';
import 'core/widgets/auto_dismiss_message.dart';
import 'features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  configureMeetingFeatureHost(_buildMeetingWorkspaceShell);
  configureServiceWorkspaceShell(_buildMeetingWorkspaceShell);
  configureTimeFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    errorText: (error) =>
        error is ApiException ? error.message : error.toString(),
    messageBuilder: ({required message, required error, required onClose}) =>
        AutoDismissMessage(message: message, error: error, onClose: onClose),
    pageSizeProvider: () => companySetupController.pageSize,
    listLayout: const TimeListLayout(
      contentMargin: EdgeInsets.all(LaooLayout.cardMargin),
      cardPadding: EdgeInsets.all(LaooLayout.cardPadding),
      cardSpacing: LaooLayout.cardSpacing,
      paginationHeight: LaooLayout.paginationCardHeight,
      captionStyle: LaooTypography.screenCaptionStyle,
    ),
    uiTokens: TimeUiTokens(
      contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
      cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
      cardSpacing: LaooLayout.cardSpacing,
      itemSpacing: 6,
      radius: LaooRadius.xs,
      compactBreakpoint: 900,
      paginationHeight: LaooLayout.paginationCardHeight,
      captionStyle: LaooTypography.screenCaptionStyle,
      sectionStyle: const TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.sectionTitle,
        height: LaooTypography.titleLineHeight,
        fontWeight: LaooTypography.emphasizedWeight,
        color: LaooColors.textPrimary,
      ),
      inputStyle: const TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.inputText,
        height: LaooTypography.inputLineHeight,
        color: LaooColors.textPrimary,
      ),
      tableStyle: const TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.tableBody,
        height: LaooTypography.bodyLineHeight,
        color: LaooColors.textPrimary,
      ),
      buttonStyle: const TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.button,
        fontWeight: LaooTypography.emphasizedWeight,
      ),
      buttonHeight: LaooTypography.buttonHeight,
      primaryColor: LaooColors.green,
      borderColor: LaooColors.border,
      backgroundColor: LaooColors.background,
      businessDate: DateTime.now(),
    ),
  );
  configureVisitorFeatureHost(_buildMeetingWorkspaceShell);
  runApp(const LaooApp());
}

Widget _buildMeetingWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  return SupportWorkspaceShell(
    menuScope: WorkspaceMenuScope.company,
    pageTitle: pageTitle,
    activeMenu: activeMenu,
    child: child,
  );
}
