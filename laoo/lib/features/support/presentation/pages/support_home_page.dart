import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../widgets/support_workspace_shell.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: 'หน้าหลัก',
      activeMenu: 'home',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1250),
            child: const _WorkspaceContent(),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เมนูหลัก',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100
                ? 4
                : width >= 720
                ? 3
                : width >= 480
                ? 2
                : 1;
            const gap = 14.0;
            final itemWidth = (width - gap * (columns - 1)) / columns;

            final cards = [
              _MenuCard(
                icon: Icons.handshake_outlined,
                title: 'Partner',
                accent: accent,
                onTap: () => context.goNamed(RouteNames.partner),
              ),
              _MenuCard(
                icon: Icons.apartment_outlined,
                title: 'Company',
                accent: accent,
                onTap: () => context.goNamed(RouteNames.company),
              ),
              _MenuCard(
                icon: Icons.account_tree_outlined,
                title: 'Branch',
                accent: accent,
                onTap: () => context.goNamed(RouteNames.branch),
              ),
              _MenuCard(
                icon: Icons.support_agent_outlined,
                title: 'Laoo User',
                accent: accent,
                onTap: () => context.goNamed(RouteNames.laooUser),
              ),
              _MenuCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Role / Permission',
                accent: accent,
                onTap: () => context.goNamed(RouteNames.permission),
              ),
              _MenuCard(
                icon: Icons.receipt_long_outlined,
                title: 'Audit Log',
                accent: accent,
                onTap: () => context.goNamed(RouteNames.audit),
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards)
                  SizedBox(width: itemWidth, height: 130, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.accent,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.md),
        side: const BorderSide(color: LaooColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LaooRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
