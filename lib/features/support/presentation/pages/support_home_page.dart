import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_menu_route_registry.dart';
import '../../../../core/favorites/user_favorite_repository.dart';
import '../../../../core/navigation/navigation_menu.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/navigation/navigation_icon_resolver.dart';
import '../widgets/support_workspace_shell.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: 'หน้าหลัก',
      activeMenu: 'home',
      showMobileMenuButton: true,
      child: const _MobileSupportHomeContent(),
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
              (AppMenuRouteRegistry.byMenuCode(item.menuCode) != null ||
                  (item.routePath?.trim().isNotEmpty ?? false)),
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

        final width = MediaQuery.sizeOf(context).width;
        final tileSize = width >= 900 ? 124.0 : 80.0;
        final horizontalPadding = width >= 900 ? 24.0 : 10.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            24,
          ),
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
                              size: tileSize,
                              onTap: () => _openMenu(
                                favorite.menuCode,
                                routePath: favorite.routePath,
                              ),
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
                        size: tileSize,
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
                        size: tileSize,
                        onTap: () =>
                            _openMenu(item.code, routePath: item.routePath),
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

  void _openMenu(String menuCode, {String? routePath}) {
    final route = AppMenuRouteRegistry.byMenuCode(menuCode);
    if (route != null) {
      context.goNamed(route.goRouteName);
      return;
    }
    final path = routePath?.trim();
    if (path != null && path.isNotEmpty) context.go(path);
  }

  IconData _icon(String? name) => resolveNavigationIcon(name);
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
