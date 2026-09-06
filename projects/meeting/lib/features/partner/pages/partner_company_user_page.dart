import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

class PartnerCompanyUserPage extends StatefulWidget {
  const PartnerCompanyUserPage({super.key});

  @override
  State<PartnerCompanyUserPage> createState() => _PartnerCompanyUserPageState();
}

class _PartnerCompanyUserPageState extends State<PartnerCompanyUserPage> {
  static const _contract = CompanyUserScreenContracts.partner;
  late final ApiClient _api;
  late final CompanyUserRepository _repository;
  String _caption = 'เธเธนเนเนเธเนเธเธฒเธเธเธฃเธดเธฉเธฑเธ—';

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _repository = CompanyUserRepository(_api);
    _resolveCaption();
  }

  Future<void> _resolveCaption() async {
    try {
      final caption = await NavigationMenuRepository(apiClient: _api)
          .resolveMenuName(
            menuCode: _contract.menuCode,
            routeName: _contract.routeName,
            fallback: _caption,
          );
      if (mounted) setState(() => _caption = caption);
    } catch (_) {
      // Keep the database-aligned fallback when navigation is unavailable.
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: _contract.menuCode,
      menuScope: WorkspaceMenuScope.partner,
      child: CompanyUserWorkspace(
        caption: _caption,
        repository: _repository,
        errorText: (error) =>
            error is ApiException ? error.message : error.toString(),
        titleBuilder: (context, title, showFavorite) => WorkspacePageTitle(
          title: title,
          favoriteKey: showFavorite ? _contract.menuCode : null,
        ),
        messageBuilder: (context, message, error, onClose) =>
            AutoDismissMessage(
              key: ValueKey((message, error)),
              message: message,
              error: error,
              onClose: onClose,
            ),
        tokens: const CompanyUserUiTokens(
          contentMargin: EdgeInsets.all(LaooLayout.cardMargin),
          cardPadding: EdgeInsets.all(LaooLayout.cardPadding),
          cardSpacing: LaooLayout.cardSpacing,
          itemSpacing: 6,
          radius: LaooRadius.xs,
          compactBreakpoint: 900,
          paginationHeight: LaooLayout.paginationCardHeight,
          captionStyle: TextStyle(
            fontFamily: LaooTypography.fontFamily,
            fontFamilyFallback: LaooTypography.fontFallback,
            fontSize: LaooTypography.workspaceCaption,
            height: LaooTypography.titleLineHeight,
            fontWeight: LaooTypography.workspaceCaptionWeight,
            color: Colors.black,
          ),
        ),
        screenType: _contract.screenType,
        pageSize: companySetupController.pageSize,
      ),
    );
  }
}
