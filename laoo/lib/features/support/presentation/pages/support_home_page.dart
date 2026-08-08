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
            if (!compact) const SizedBox(width: 184, child: _Sidebar()),
            Expanded(
              child: Column(
                children: [
                  if (!compact) const _TopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1250),
                          child: const _WorkspaceContent(),
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

class _Sidebar extends StatefulWidget {
  const _Sidebar();

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final Set<String> _expandedGroups = <String>{'organization'};

  void _toggleGroup(String key) {
    setState(() {
      if (_expandedGroups.contains(key)) {
        _expandedGroups.remove(key);
      } else {
        _expandedGroups.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LaooColors.greenDark,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandBlock(),
          const SizedBox(height: 10),
          const _UserBlock(),
          const SizedBox(height: 10),
          const _HomeItem(),
          const SizedBox(height: 3),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _MenuGroup(
                    title: 'จัดการองค์กร',
                    icon: Icons.business_outlined,
                    expanded: _expandedGroups.contains('organization'),
                    onToggle: () => _toggleGroup('organization'),
                    children: [
                      _SubMenuItem(
                        label: 'Partner',
                        icon: Icons.handshake_outlined,
                        onTap: () {
                          appRouter.goNamed(RouteNames.partner);
                        },
                      ),
                      const _SubMenuItem(
                        label: 'Company',
                        icon: Icons.apartment_outlined,
                      ),
                    ],
                  ),
                  _MenuGroup(
                    title: 'ระบบและผู้ใช้งาน',
                    icon: Icons.apps_outlined,
                    expanded: _expandedGroups.contains('system'),
                    onToggle: () => _toggleGroup('system'),
                    children: const [
                      _SubMenuItem(
                        label: 'Project',
                        icon: Icons.account_tree_outlined,
                      ),
                      _SubMenuItem(label: 'User', icon: Icons.person_outline),
                      _SubMenuItem(
                        label: 'Permission',
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                    ],
                  ),
                  _MenuGroup(
                    title: 'ตรวจสอบระบบ',
                    icon: Icons.fact_check_outlined,
                    expanded: _expandedGroups.contains('audit'),
                    onToggle: () => _toggleGroup('audit'),
                    children: const [
                      _SubMenuItem(
                        label: 'Audit Log',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ],
                  ),
                  _MenuGroup(
                    title: 'ตั้งค่าระบบ',
                    icon: Icons.settings_outlined,
                    expanded: _expandedGroups.contains('settings'),
                    onToggle: () => _toggleGroup('settings'),
                    children: const [
                      _SubMenuItem(label: 'Setting', icon: Icons.tune_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAOO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'SOLUTIONS',
            style: TextStyle(
              color: Color(0xFF8EE6B5),
              fontSize: 8.8,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: LaooColors.greenLight,
            child: Icon(
              Icons.support_agent_rounded,
              size: 16,
              color: LaooColors.greenDark,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Support',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Laoo Support',
                  style: TextStyle(
                    color: Color(0xFFA8CBBB),
                    fontSize: 9.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeItem extends StatelessWidget {
  const _HomeItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 29,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          Icon(Icons.home_outlined, size: 15, color: LaooColors.greenDark),
          SizedBox(width: 7),
          Text(
            'หน้าหลัก',
            style: TextStyle(
              color: LaooColors.greenDark,
              fontSize: 11.8,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                height: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Row(
                    children: [
                      Icon(icon, size: 15, color: const Color(0xFFE3EFE9)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.8,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 16,
                        color: const Color(0xFFBBD4C8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: expanded
                ? Column(children: children)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SubMenuItem extends StatelessWidget {
  const _SubMenuItem({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 25,
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 6),
            child: Row(
              children: [
                Icon(icon, size: 13, color: const Color(0xFFAED0C0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFDCEAE3),
                      fontSize: 10.8,
                      height: 1,
                      fontWeight: FontWeight.w500,
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: LaooColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            'หน้าหลัก',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          SizedBox(
            width: 300,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ค้นหาเมนู, ข้อมูล...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 21),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
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
        const SizedBox(height: 22),
        const Text(
          'Main Menu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100
                ? 4
                : width >= 720
                ? 3
                : 2;
            const gap = 12.0;
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
                  SizedBox(width: itemWidth, height: 170, child: card),
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
      width: 82,
      height: 64,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: LaooColors.greenLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 15, color: LaooColors.green),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.2,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LaooColors.greenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 21, color: LaooColors.green),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: LaooColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
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
