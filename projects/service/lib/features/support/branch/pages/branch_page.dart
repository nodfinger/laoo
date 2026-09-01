import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../partner/data/partner_company_repository.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/branch_repository.dart' as local;

class BranchPage extends StatefulWidget {
  const BranchPage({super.key, this.menuScope = WorkspaceMenuScope.support});

  final WorkspaceMenuScope menuScope;

  @override
  State<BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<BranchPage> {
  late final ApiClient _api;
  late final LaooOwnerScope _scope;
  late final ScreenContract _contract;
  late final local.BranchRepository _repository;
  late final PartnerCompanyRepository _companyRepository;
  String _caption = 'สาขา';

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _scope = switch (widget.menuScope) {
      WorkspaceMenuScope.support => LaooOwnerScope.support,
      WorkspaceMenuScope.partner => LaooOwnerScope.partner,
      WorkspaceMenuScope.company => LaooOwnerScope.company,
    };
    _contract = BranchScreenContracts.forScope(_scope);
    _repository = local.BranchRepository(scope: _scope, api: _api);
    _companyRepository = PartnerCompanyRepository(apiClient: _api);
    _resolveCaption();
  }

  Future<void> _resolveCaption() async {
    try {
      final value = await NavigationMenuRepository(apiClient: _api)
          .resolveMenuName(
            menuCode: _contract.menuCode,
            routeName: _contract.routeName,
            fallback: _caption,
          );
      if (mounted) setState(() => _caption = value);
    } catch (_) {}
  }

  Future<List<BranchCompanyOption>> _loadCompanies() async {
    if (_scope == LaooOwnerScope.company) return const [];
    final values = await _companyRepository.getCompanies(
      support: _scope == LaooOwnerScope.support,
    );
    return values
        .map(
          (value) => BranchCompanyOption(
            companyId: value.companyId,
            name: value.companyNameTh,
          ),
        )
        .toList(growable: false);
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
      menuScope: widget.menuScope,
      child: BranchWorkspace(
        caption: _caption,
        repository: _repository,
        loadCompanies: _loadCompanies,
        errorText: (error) =>
            error is ApiException ? error.message : error.toString(),
        screenType: _contract.screenType,
        companyScope: _scope == LaooOwnerScope.company,
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
