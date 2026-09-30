import 'package:flutter/material.dart';
import 'package:laoo_meeting/meeting_feature.dart';
import 'package:laoo_five_s/five_s_feature.dart';
import 'package:laoo_survey/survey_feature.dart';
import 'package:laoo_expense/expense_feature.dart';
import 'package:laoo_project/project_feature.dart';
import 'package:laoo_intranet/intranet_feature.dart';
import 'package:laoo_vote/vote_feature.dart';
import 'package:laoo_pos/pos_feature.dart';
import 'package:laoo_sales/sales_feature.dart';
import 'package:laoo_evaluation/evaluation_feature.dart';
import 'package:laoo_service/service_feature.dart';
import 'package:laoo_time/time_feature.dart';
import 'package:laoo_training/training_feature.dart';
import 'package:laoo_gate_pass/gate_pass_feature.dart';
import 'package:laoo_visitor/visitor_feature.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'app/laoo_app.dart';
import 'app/theme/laoo_design_tokens.dart';
import 'app/theme/laoo_typography.dart';
import 'app/theme/workspace_theme_presets.dart';
import 'core/api/api_client.dart';
import 'core/api/api_exception.dart';
import 'core/company_setup/company_setup_controller.dart';
import 'core/company_setup/company_date_formatter.dart';
import 'core/navigation/navigation_menu_repository.dart';
import 'core/widgets/auto_dismiss_message.dart';
import 'core/widgets/timed_snack_bar.dart';
import 'features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  configureFiveSFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    menuTitleResolver: (menuCode, fallback) => NavigationMenuRepository()
        .resolveMenuName(menuCode: menuCode, fallback: fallback),
    messagePresenter: (context, {required message, required error}) =>
        showTimedSnackBar(context, message: message, error: error),
    upload: (path, {required fileName, required bytes, fields}) {
      final client = ApiClient();
      return client
          .upload(path, fileName: fileName, bytes: bytes, fields: fields)
          .whenComplete(client.dispose);
    },
    uiTokensProvider: () {
      final theme = workspaceThemeController.value;
      return LaooWorkspaceUiTokens(
        contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
        cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
        sectionSpacing: 6,
        captionFilterSpacing: 6,
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
        primaryColor: theme.primary,
        borderColor: theme.border,
        backgroundColor: LaooColors.background,
      );
    },
  );
  configureSurveyFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    menuTitleResolver: (menuCode, fallback) => NavigationMenuRepository()
        .resolveMenuName(menuCode: menuCode, fallback: fallback),
    messagePresenter: (context, {required message, required error}) =>
        showTimedSnackBar(context, message: message, error: error),
    uiTokensProvider: _surveyWorkspaceTokens,
  );
  configureExpenseFeatureHost(_buildMeetingWorkspaceShell);
  configureProjectFeatureHost(_buildMeetingWorkspaceShell);
  configureIntranetFeatureHost(_buildMeetingWorkspaceShell);
  configureVoteFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
  );
  configurePosFeatureHost(_buildMeetingWorkspaceShell);
  configureSalesFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    menuTitleResolver: (menuCode, fallback) => NavigationMenuRepository()
        .resolveMenuName(menuCode: menuCode, fallback: fallback),
    messagePresenter: (context, {required message, required error}) =>
        showTimedSnackBar(context, message: message, error: error),
    uiTokensProvider: () {
      final theme = workspaceThemeController.value;
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
        primaryColor: theme.primary,
        borderColor: theme.border,
        backgroundColor: LaooColors.background,
      );
    },
  );
  configureEvaluationFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    errorText: (error) =>
        error is ApiException ? error.message : 'กรุณาลองใหม่อีกครั้ง',
    dateTimeText: (value) {
      final setup = companySetupController.current;
      final date = setup == null
          ? CompanyDateFormatter.formatDateByYearFormat(value, 'AD')
          : CompanyDateFormatter.formatDate(value, setup);
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$date $hour:$minute';
    },
    menuTitleResolver: (menuCode, fallback) => NavigationMenuRepository()
        .resolveMenuName(menuCode: menuCode, fallback: fallback),
    messagePresenter: (context, {required message, required error}) =>
        showTimedSnackBar(context, message: message, error: error),
    uiTokensProvider: () {
      final theme = workspaceThemeController.value;
      return EvaluationUiTokens(
        contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
        cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
        sectionSpacing: LaooLayout.listSectionSpacing,
        itemSpacing: LaooLayout.listItemSpacing,
        radius: LaooRadius.xs,
        popupHeaderMinHeight: LaooLayout.popupHeaderMinHeight,
        popupFieldSpacing: LaooLayout.popupFieldSpacing,
        buttonHeight: LaooTypography.buttonHeight,
        paginationCardHeight: LaooLayout.paginationCardHeight,
        compactBreakpoint: 900,
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
        buttonStyle: const TextStyle(
          fontFamily: LaooTypography.fontFamily,
          fontFamilyFallback: LaooTypography.fontFallback,
          fontSize: LaooTypography.button,
          fontWeight: LaooTypography.emphasizedWeight,
        ),
        primaryColor: theme.primary,
        borderColor: theme.border,
        backgroundColor: LaooColors.background,
        popupSurfaceColor: LaooColors.white,
        dangerColor: LaooColors.error,
        dangerSurfaceColor: LaooColors.error.withValues(alpha: 0.08),
      );
    },
  );
  configureMeetingFeatureHost(_buildMeetingWorkspaceShell);
  configureServiceWorkspaceShell(_buildMeetingWorkspaceShell);
  configureGatePassFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    menuTitleResolver: (menuCode, fallback) => NavigationMenuRepository()
        .resolveMenuName(menuCode: menuCode, fallback: fallback),
    messagePresenter: (context, {required message, required error}) =>
        showTimedSnackBar(context, message: message, error: error),
    upload: (path, {required fileName, required bytes}) {
      final client = ApiClient();
      return client
          .upload(path, fileName: fileName, bytes: bytes)
          .whenComplete(client.dispose);
    },
    uiTokensProvider: () {
      final theme = workspaceThemeController.value;
      return GatePassUiTokens(
        contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
        cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
        sectionSpacing: LaooLayout.listSectionSpacing,
        itemSpacing: LaooLayout.listItemSpacing,
        radius: LaooRadius.xs,
        buttonHeight: LaooTypography.buttonHeight,
        paginationCardHeight: LaooLayout.paginationCardHeight,
        compactBreakpoint: 900,
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
        primaryColor: theme.primary,
        borderColor: theme.border,
      );
    },
  );
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
    uiTokensProvider: () {
      final theme = workspaceThemeController.value;
      return TimeUiTokens(
        paginationButtonSize: LaooLayout.paginationButtonSize,
        dialogInsetPadding: LaooLayout.dialogInsetPadding,
        popupHeaderMinHeight: LaooLayout.popupHeaderMinHeight,
        popupFieldSpacing: LaooLayout.popupFieldSpacing,
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
        inputLabelStyle: TextStyle(
          fontFamily: LaooTypography.fontFamily,
          fontFamilyFallback: LaooTypography.fontFallback,
          fontSize: LaooTypography.materialFloatingLabelSource,
          height: LaooTypography.bodyLineHeight,
          color: theme.primary,
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
        primaryColor: theme.primary,
        borderColor: theme.border,
        backgroundColor: LaooColors.background,
        businessDate: DateTime.now(),
      );
    },
  );
  configureTrainingFeatureHost(
    _buildMeetingWorkspaceShell,
    apiClientFactory: ApiClient.new,
    apiClientDisposer: (client) => (client as ApiClient).dispose(),
    errorText: (error) =>
        error is ApiException ? error.message : error.toString(),
    messageBuilder: ({required message, required error, required onClose}) =>
        AutoDismissMessage(message: message, error: error, onClose: onClose),
    pageSizeProvider: () => companySetupController.pageSize,
    uiTokensProvider: () {
      final theme = workspaceThemeController.value;
      return TrainingUiTokens(
        popupFieldSpacing: LaooLayout.popupFieldSpacing,
        popupHeaderMinHeight: LaooLayout.popupHeaderMinHeight,
        paginationButtonSize: LaooLayout.paginationButtonSize,
        dialogInsetPadding: LaooLayout.dialogInsetPadding,
        workspace: LaooWorkspaceUiTokens(
          contentMargin: const EdgeInsets.all(LaooLayout.cardMargin),
          cardPadding: const EdgeInsets.all(LaooLayout.cardPadding),
          sectionSpacing: LaooLayout.listSectionSpacing,
          captionFilterSpacing: 6,
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
          primaryColor: theme.primary,
          borderColor: theme.border,
          backgroundColor: LaooColors.background,
        ),
        primaryColor: theme.primary,
        borderColor: theme.border,
      );
    },
  );
  configureVisitorFeatureHost(
    _buildMeetingWorkspaceShell,
    uiTokensProvider: () => const VisitorUiTokens(
      cardMargin: LaooLayout.cardMargin,
      cardPadding: LaooLayout.cardPadding,
      cardSpacing: LaooLayout.cardSpacing,
      listSectionSpacing: LaooLayout.listSectionSpacing,
      listItemSpacing: LaooLayout.listItemSpacing,
      paginationCardHeight: LaooLayout.paginationCardHeight,
      paginationButtonSize: LaooLayout.paginationButtonSize,
      popupFieldSpacing: LaooLayout.popupFieldSpacing,
      dialogInsetPadding: LaooLayout.dialogInsetPadding,
      popupHeaderMinHeight: LaooLayout.popupHeaderMinHeight,
      radius: LaooRadius.xs,
      buttonHeight: LaooTypography.buttonHeight,
      buttonFontSize: LaooTypography.button,
      floatingLabelSource: LaooTypography.materialFloatingLabelSource,
      captionStyle: LaooTypography.screenCaptionStyle,
    ),
  );
  runApp(const LaooApp());
}

LaooWorkspaceUiTokens _surveyWorkspaceTokens() {
  final theme = workspaceThemeController.value;
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
    primaryColor: theme.primary,
    borderColor: theme.border,
    backgroundColor: LaooColors.background,
  );
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
