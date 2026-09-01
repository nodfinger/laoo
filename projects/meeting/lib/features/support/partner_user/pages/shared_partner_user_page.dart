import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/shared_partner_user_repository.dart' as local;

class PartnerUserPage extends StatefulWidget {
  const PartnerUserPage({super.key});

  @override
  State<PartnerUserPage> createState() => _PartnerUserPageState();
}

class _PartnerUserPageState extends State<PartnerUserPage> {
  static const _contract = PartnerUserScreenContracts.support;
  late final ApiClient _api;
  late final local.PartnerUserRepository _repository;
  String _caption = 'Partner';

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _repository = local.PartnerUserRepository(api: _api);
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

  Future<List<PartnerUserOwnerOption>> _loadOwners() async {
    final values = await _api.get('/api/support/partners') as List;
    return values
        .whereType<Map>()
        .map(
          (value) =>
              PartnerUserOwnerOption.fromJson(Map<String, dynamic>.from(value)),
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
      activeMenu: _contract.routeName,
      child: PartnerUserWorkspace(
        caption: _caption,
        repository: _repository,
        loadOwners: _loadOwners,
        errorText: (error) =>
            error is ApiException ? error.message : error.toString(),
        screenType: _contract.screenType,
        titleBuilder: (context, title, showFavorite) => WorkspacePageTitle(
          title: title,
          favoriteKey: showFavorite ? _contract.routeName : null,
        ),
        messageBuilder: (context, message, error, onClose) =>
            AutoDismissMessage(
              key: ValueKey((message, error)),
              message: message,
              error: error,
              onClose: onClose,
            ),
        tokens: const PartnerUserUiTokens(
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
