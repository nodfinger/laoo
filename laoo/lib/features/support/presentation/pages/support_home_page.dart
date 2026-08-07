import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: compact ? const Drawer(child: _Sidebar()) : null,
      appBar: compact
          ? AppBar(
              title: const Text('Laoo Support'),
              backgroundColor: Colors.white,
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!compact) const SizedBox(width: 188, child: _Sidebar()),
            Expanded(
              child: Column(
                children: [
                  if (!compact) const _TopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 1250),
                          child: _WorkspaceContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LaooColors.greenDark,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'LAOO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Text(
            'SOLUTIONS',
            style: TextStyle(
              color: Color(0xFF8EE6B5),
              letterSpacing: 2.4,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const _UserBlock(),
          const SizedBox(height: 12),
          const _SideItem(
            icon: Icons.home_outlined,
            label: 'หน้าหลัก',
            selected: true,
          ),
          const _SideItem(icon: Icons.star_outline_rounded, label: 'Favorite'),
          _SideItem(
            icon: Icons.handshake_outlined,
            label: 'Partner',
            onTap: () {
              appRouter.goNamed(RouteNames.partner);
            },
          ),
          const _SideItem(icon: Icons.apartment_outlined, label: 'Company'),
          const _SideItem(icon: Icons.account_tree_outlined, label: 'Project'),
          const _SideItem(icon: Icons.person_outline, label: 'User'),
          const _SideItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Permission',
          ),
          const _SideItem(
            icon: Icons.receipt_long_outlined,
            label: 'Audit Log',
          ),
          const Spacer(),
          const _SideItem(icon: Icons.settings_outlined, label: 'ตั้งค่า'),
        ],
      ),
    );
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: LaooColors.greenLight,
          child: Icon(Icons.support_agent_rounded, color: LaooColors.greenDark),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Support',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Laoo Support',
                style: TextStyle(color: Color(0xFFA8CBBB), fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? LaooColors.greenDark
                      : const Color(0xFFD2E5DC),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? LaooColors.greenDark : Colors.white,
                    fontSize: 12.5,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: LaooColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            'หน้าหลัก',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          SizedBox(
            width: 320,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ค้นหาเมนู, ข้อมูล...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Favorite Menu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Favorite(
              icon: Icons.handshake_outlined,
              label: 'Partner',
              onTap: () {
                appRouter.goNamed(RouteNames.partner);
              },
            ),
            const _Favorite(icon: Icons.apartment_outlined, label: 'Company'),
            const _Favorite(icon: Icons.person_outline, label: 'User'),
            const _Favorite(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Permission',
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Main Menu',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100
                ? 4
                : width >= 720
                ? 3
                : 2;
            const gap = 14.0;
            final itemWidth = (width - (gap * (columns - 1))) / columns;

            final cards = <Widget>[
              _MetricCard(
                icon: Icons.handshake_outlined,
                title: 'Partner',
                subtitle: 'จัดการผู้แทนจำหน่าย',
                value: '128',
                onTap: () {
                  appRouter.goNamed(RouteNames.partner);
                },
              ),
              const _MetricCard(
                icon: Icons.apartment_outlined,
                title: 'Company',
                subtitle: 'จัดการลูกค้า',
                value: '350',
              ),
              const _MetricCard(
                icon: Icons.account_tree_outlined,
                title: 'Project',
                subtitle: 'จัดการโครงการ',
                value: '86',
              ),
              const _MetricCard(
                icon: Icons.person_outline,
                title: 'User',
                subtitle: 'จัดการผู้ใช้งาน',
                value: '1,250',
              ),
              const _MetricCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Permission',
                subtitle: 'จัดการสิทธิ์',
                value: '98%',
              ),
              const _MetricCard(
                icon: Icons.receipt_long_outlined,
                title: 'Audit Log',
                subtitle: 'บันทึกการใช้งาน',
                value: '12,458',
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards)
                  SizedBox(width: itemWidth, height: 180, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Favorite extends StatelessWidget {
  const _Favorite({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      height: 72,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: LaooColors.greenLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: LaooColors.green),
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LaooRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: LaooColors.greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: LaooColors.green),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: LaooColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
