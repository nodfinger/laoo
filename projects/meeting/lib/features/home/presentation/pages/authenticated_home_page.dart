import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../../../partner/pages/partner_company_page.dart';

class AuthenticatedHomePage extends StatelessWidget {
  const AuthenticatedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = appAuthController.isPartnerUser
        ? WorkspaceMenuScope.partner
        : WorkspaceMenuScope.company;

    return SupportWorkspaceShell(
      pageTitle: 'หน้าหลัก',
      activeMenu: 'home',
      menuScope: scope,
      child: const _DashboardContent(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    final session = appAuthController.session;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionCard(
            child: WorkspacePageTitle(title: 'หน้าหลัก'),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Text(
            'ยินดีต้อนรับ ${session?.displayName ?? session?.username ?? '-'}',
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Wrap(
            spacing: LaooLayout.cardSpacing,
            runSpacing: LaooLayout.cardSpacing,
            children: [
              _InfoCard(
                icon: Icons.badge_outlined,
                label: 'ประเภทผู้ใช้งาน',
                value: session?.userType ?? '-',
              ),
              _InfoCard(
                icon: Icons.business_outlined,
                label: 'บริษัท / Partner',
                value: session?.partnerId != null
                    ? 'Partner #${session!.partnerId}'
                    : 'Company #${session?.companyId ?? '-'}',
              ),
              _InfoCard(
                icon: Icons.folder_outlined,
                label: 'Project',
                value: session?.projectCode ?? '-',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompanyModulePlaceholderPage extends StatelessWidget {
  const CompanyModulePlaceholderPage({
    required this.title,
    required this.menuScope,
    required this.activeMenu,
    super.key,
  });

  final String title;
  final WorkspaceMenuScope menuScope;
  final String activeMenu;

  @override
  Widget build(BuildContext context) {
    if (menuScope == WorkspaceMenuScope.partner &&
        activeMenu == 'partnerCompanies') {
      return const PartnerCompanyPage();
    }
    return SupportWorkspaceShell(
      pageTitle: title,
      activeMenu: activeMenu,
      menuScope: menuScope,
      child: Center(child: Text('$title จะพัฒนาต่อในขั้นตอนถัดไป')),
    );
  }
}
