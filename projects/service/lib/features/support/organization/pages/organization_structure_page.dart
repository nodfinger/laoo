import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/organization_repository.dart' as local;

class OrganizationStructurePage extends StatefulWidget {
  const OrganizationStructurePage({super.key});

  @override
  State<OrganizationStructurePage> createState() =>
      _OrganizationStructurePageState();
}

class _OrganizationStructurePageState extends State<OrganizationStructurePage> {
  late final ApiClient _api;
  late final LaooOwnerScope _scope;
  late final ScreenContract _contract;
  late final local.OrganizationRepository _repository;
  String _caption = 'โครงสร้างองค์กร';

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _scope = appAuthController.isPartnerUser
        ? LaooOwnerScope.partner
        : appAuthController.isCompanyUser
        ? LaooOwnerScope.company
        : LaooOwnerScope.support;
    _contract = OrganizationScreenContracts.forScope(_scope);
    _repository = local.OrganizationRepository(scope: _scope, api: _api);
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
    } catch (_) {}
  }

  WorkspaceMenuScope get _menuScope => switch (_scope) {
    LaooOwnerScope.support => WorkspaceMenuScope.support,
    LaooOwnerScope.partner => WorkspaceMenuScope.partner,
    LaooOwnerScope.company => WorkspaceMenuScope.company,
  };

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
      menuScope: _menuScope,
      child: OrganizationStructureWorkspace(
        caption: _caption,
        repository: _repository,
        errorText: (error) =>
            error is ApiException ? error.message : error.toString(),
        screenType: _contract.screenType,
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
        tokens: const SharedAdminUiTokens(
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
      ),
    );
  }
}
