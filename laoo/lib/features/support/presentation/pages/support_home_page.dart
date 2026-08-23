import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_menu_route_registry.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../core/favorites/user_favorite_repository.dart';
import '../../../../core/navigation/navigation_menu.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../widgets/support_workspace_shell.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: 'หน้าหลัก',
      activeMenu: 'home',
      showMobileMenuButton: true,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600
            ? const _MobileSupportHomeContent()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1250),
                    child: const _WorkspaceContent(),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MobileSupportHomeContent extends StatefulWidget {
  const _MobileSupportHomeContent();

  @override
  State<_MobileSupportHomeContent> createState() =>
      _MobileSupportHomeContentState();
}

class _MobileSupportHomeContentState extends State<_MobileSupportHomeContent> {
  final _menusRepository = NavigationMenuRepository();
  final _favoritesRepository = UserFavoriteRepository();
  late Future<List<NavigationMenuGroup>> _menus;
  List<UserFavorite> _favorites = const [];
  String? _selectedGroupCode;

  @override
  void initState() {
    super.initState();
    _menus = _menusRepository.getMenus();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesRepository.getAll();
    final groups = await _menus;
    final visibleCodes = groups
        .expand((group) => group.items)
        .map((item) => item.code.trim().toUpperCase())
        .toSet();
    final valid = favorites
        .where(
          (item) =>
              visibleCodes.contains(item.menuCode.trim().toUpperCase()) &&
              AppMenuRouteRegistry.byMenuCode(item.menuCode) != null,
        )
        .toList();
    for (final item in favorites.where((item) => !valid.contains(item))) {
      await _favoritesRepository.remove(item.menuCode);
    }
    if (mounted) setState(() => _favorites = valid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NavigationMenuGroup>>(
      future: _menus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton.icon(
              onPressed: () => setState(
                () => _menus = _menusRepository.getMenus(refresh: true),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('โหลดเมนูใหม่'),
            ),
          );
        }

        final groups = snapshot.data ?? const <NavigationMenuGroup>[];
        final selected = groups.firstWhere(
          (group) => group.code == _selectedGroupCode,
          orElse: () => groups.isNotEmpty
              ? groups.first
              : const NavigationMenuGroup(code: '', name: '', items: []),
        );
        if (_selectedGroupCode == null && groups.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedGroupCode = groups.first.code);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MobileSection(
                title: 'รายการโปรด',
                showTitle: true,
                child: _favorites.isEmpty
                    ? const _MobileEmptyTile(text: 'ยังไม่มีรายการโปรด')
                    : Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: [
                          for (final favorite in _favorites)
                            _MobileMenuTile(
                              label: favorite.menuName,
                              icon: _icon(favorite.iconName),
                              size: 80,
                              onTap: () => _openMenu(favorite.menuCode),
                            ),
                        ],
                      ),
              ),
              _MobileSection(
                title: 'กลุ่มเมนู',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (final group in groups)
                      _MobileMenuTile(
                        label: group.name,
                        icon: _icon(group.iconName),
                        size: 80,
                        selected: group.code == selected.code,
                        onTap: () =>
                            setState(() => _selectedGroupCode = group.code),
                      ),
                  ],
                ),
              ),
              _MobileSection(
                title: selected.name.isEmpty
                    ? 'เมนูในกลุ่ม'
                    : 'เมนูในกลุ่ม : ${selected.name}',
                child: Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    for (final item in selected.items)
                      _MobileMenuTile(
                        label: item.name,
                        icon: _icon(item.iconName),
                        size: 80,
                        onTap: () => _openMenu(item.code),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMenu(String menuCode) {
    final route = AppMenuRouteRegistry.byMenuCode(menuCode)?.goRouteName;
    if (route != null) context.goNamed(route);
  }

  IconData _icon(String? name) => switch (name) {
    'home' => Icons.home_outlined,
    'people' => Icons.people_outline,
    'settings' => Icons.settings_outlined,
    'business' => Icons.business_outlined,
    'support' => Icons.support_outlined,
    'list' => Icons.list_alt_outlined,
    'apartment' => Icons.apartment_outlined,
    _ => Icons.apps_outlined,
  };
}

class _MobileSection extends StatelessWidget {
  const _MobileSection({
    required this.title,
    required this.child,
    this.showTitle = false,
  });

  final String title;
  final Widget child;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(1, 8, 1, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class _MobileMenuTile extends StatelessWidget {
  const _MobileMenuTile({
    required this.label,
    required this.icon,
    this.size = 120,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final compact = size <= 80;
    return SizedBox(
      width: size,
      height: size,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: selected ? 2 : 1,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(compact ? 4 : 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: compact ? 22 : 30),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  label,
                  style: compact ? Theme.of(context).textTheme.bodySmall : null,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileEmptyTile extends StatelessWidget {
  const _MobileEmptyTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
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
