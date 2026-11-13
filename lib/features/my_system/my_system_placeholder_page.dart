import 'package:flutter/material.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class MySystemPlaceholderPage extends StatelessWidget {
  const MySystemPlaceholderPage({super.key, required this.menuCode});
  final String menuCode;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: NavigationMenuRepository().findMenu(menuCode: menuCode),
    builder: (context, snapshot) {
      final title = snapshot.data?.name ?? '';
      final activeMenu = switch (menuCode) {
        '68001' => 'companyApprovalSettings',
        '65001' => 'mySystemSettings',
        '65002' => 'mySystemSapPms',
        '66001' => 'mySystemTravel',
        '66002' => 'mySystemPurchase',
        '70002' => 'mySystemLegalDocumentRequest',
        '70003' => 'mySystemLegalDocumentTypes',
        _ => '',
      };
      return SupportWorkspaceShell(
        pageTitle: title,
        activeMenu: activeMenu,
        menuScope: WorkspaceMenuScope.company,
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: WorkspacePageTitle(
                    title: title,
                    favoriteKey: activeMenu,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  child: const Center(child: Text('หน้าจออยู่ระหว่างพัฒนา')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
