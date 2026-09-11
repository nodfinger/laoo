import 'package:flutter/material.dart';
import 'package:laoo_meeting/meeting_feature.dart';
import 'package:laoo_service/service_feature.dart';
import 'package:laoo_time/time_feature.dart';
import 'package:laoo_visitor/visitor_feature.dart';

import 'app/laoo_app.dart';
import 'core/api/api_client.dart';
import 'core/api/api_exception.dart';
import 'core/company_setup/company_setup_controller.dart';
import 'core/widgets/auto_dismiss_message.dart';
import 'app/theme/laoo_design_tokens.dart';
import 'app/theme/laoo_typography.dart';
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
    uiTokens: const TimeUiTokens(
      contentMargin: LaooLayout.cardMargin,
      cardPadding: LaooLayout.cardPadding,
      cardSpacing: LaooLayout.cardSpacing,
      formSpacing: 12,
      radius: LaooRadius.xs,
      paginationHeight: LaooLayout.paginationCardHeight,
      buttonHeight: LaooTypography.buttonHeight,
      backgroundColor: LaooColors.background,
      pageCaptionStyle: LaooTypography.pageCaptionStyle,
      sectionTitleStyle: TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.sectionTitle,
        fontWeight: LaooTypography.emphasizedWeight,
      ),
      inputStyle: TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.inputText,
        height: LaooTypography.inputLineHeight,
      ),
      tableStyle: TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.tableBody,
        height: LaooTypography.bodyLineHeight,
      ),
      buttonStyle: TextStyle(
        fontFamily: LaooTypography.fontFamily,
        fontFamilyFallback: LaooTypography.fontFallback,
        fontSize: LaooTypography.button,
        fontWeight: LaooTypography.emphasizedWeight,
      ),
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
