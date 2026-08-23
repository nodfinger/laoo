import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_menu_route_registry.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/favorites/user_favorite_repository.dart';
import '../../../../core/navigation/navigation_menu.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/navigation/menu_style_preferences.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../profile/pages/user_profile_dialog.dart';

final ValueNotifier<Set<String>> supportFavoritePages =
    ValueNotifier<Set<String>>(<String>{});
final ValueNotifier<int> supportFavoriteRefresh = ValueNotifier<int>(0);
final ValueNotifier<String?> mobileSelectedMenuGroup = ValueNotifier<String?>(
  null,
);
final UserFavoriteRepository _userFavoriteRepository = UserFavoriteRepository();

enum WorkspaceMenuScope { support, partner, company }

class WorkspacePageTitle extends StatelessWidget {
  const WorkspacePageTitle({super.key, required this.title, this.favoriteKey});

  final String title;
  final String? favoriteKey;

  @override
  Widget build(BuildContext context) {
    final key = favoriteKey;

    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) {
        final accent = preset.primary;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: LaooTypography.workspaceCaption,
                  fontWeight: LaooTypography.workspaceCaptionWeight,
                  color: accent,
                ),
              ),
            ),
            if (key != null) ...[
              const SizedBox(width: 6),
              ValueListenableBuilder<Set<String>>(
                valueListenable: supportFavoritePages,
                builder: (context, favorites, _) {
                  return FutureBuilder<NavigationMenuItem?>(
                    future: NavigationMenuRepository().findMenu(
                      menuCode: key,
                      routeName: key,
                    ),
                    builder: (context, snapshot) {
                      final code = snapshot.data?.code.trim() ?? key;
                      final selected = favorites.contains(code);
                      return IconButton(
                        tooltip: selected
                            ? 'นำออกจากเมนูลัดของฉัน'
                            : 'เพิ่มหน้านี้เป็นเมนูลัดของฉัน',
                        onPressed: () async {
                          final resolved = snapshot.data?.code.trim();
                          if (resolved == null || resolved.isEmpty) return;
                          final next = <String>{...favorites};
                          if (selected) {
                            next.remove(resolved);
                            await _userFavoriteRepository.remove(resolved);
                          } else {
                            next.add(resolved);
                            await _userFavoriteRepository.add(resolved);
                          }
                          supportFavoritePages.value = next;
                          supportFavoriteRefresh.value++;
                        },
                        icon: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: accent,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class SupportWorkspaceShell extends StatelessWidget {
  const SupportWorkspaceShell({
    super.key,
    required this.pageTitle,
    required this.child,
    this.activeMenu,
    this.menuScope = WorkspaceMenuScope.support,
    this.showMobileMenuButton = true,
  });

  final String pageTitle;
  final String? activeMenu;
  final Widget child;
  final WorkspaceMenuScope menuScope;
  final bool showMobileMenuButton;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) {
        final compact = MediaQuery.sizeOf(context).width < 900;
        final baseTheme = preset.toThemeData();
        final workspaceTheme = baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            surface: preset.surface,
            onSurface: preset.textPrimary,
            onSurfaceVariant: preset.textSecondary,
          ),
          popupMenuTheme: baseTheme.popupMenuTheme.copyWith(
            color: preset.surface,
            textStyle: TextStyle(
              color: preset.textPrimary,
              fontSize: LaooTypography.body,
            ),
          ),
          cardTheme: baseTheme.cardTheme.copyWith(
            color: preset.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: preset.primary.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
          ),
        );
        return Theme(
          data: workspaceTheme,
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: preset.background,
              drawer: compact
                  ? ValueListenableBuilder<bool>(
                      valueListenable: workspaceButtonMenu,
                      builder: (context, _, _) => Drawer(
                        child: _Sidebar(
                          activeMenu: activeMenu,
                          preset: preset,
                          menuScope: menuScope,
                        ),
                      ),
                    )
                  : null,
              appBar: compact
                  ? AppBar(
                      backgroundColor: preset.surface,
                      surfaceTintColor: Colors.transparent,
                      automaticallyImplyLeading: false,
                      titleSpacing: 0,
                      title: ValueListenableBuilder<bool>(
                        valueListenable: workspaceButtonMenu,
                        builder: (context, buttonMenu, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showMobileMenuButton)
                              _MobileGroupMenu(
                                preset: preset,
                                menuScope: menuScope,
                                activeMenu: activeMenu,
                                slide: true,
                              ),
                            if (showMobileMenuButton) const SizedBox(width: 4),
                            SizedBox(
                              width: showMobileMenuButton ? 145 : 155,
                              child: _BrandHeader(
                                accent: preset.primary,
                                preset: preset,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        /* IconButton(
                          tooltip: 'กลับหน้าหลัก',
                          onPressed: () =>
                              context.goNamed(RouteNames.authenticatedHome),
                          icon: Icon(
                        ), */
                        _UserMenu(preset: preset),
                        const SizedBox(width: 8),
                      ],
                    )
                  : null,
              body: ValueListenableBuilder<bool>(
                valueListenable: workspaceButtonMenu,
                builder: (context, selectedButtonMenu, _) {
                  final buttonMenu = selectedButtonMenu;
                  return SafeArea(
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            if (!compact && !buttonMenu)
                              SizedBox(
                                width: 220,
                                child: _Sidebar(
                                  activeMenu: activeMenu,
                                  preset: preset,
                                  menuScope: menuScope,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  if (!compact)
                                    _TopBar(
                                      preset: preset,
                                      buttonMenu: buttonMenu,
                                    ),
                                  if (!compact) const _FavoriteWorkspaceBar(),
                                  if (buttonMenu)
                                    Expanded(
                                      child: _ButtonMenuWorkspace(
                                        menuScope: menuScope,
                                        preset: preset,
                                        activeMenu: activeMenu,
                                        child: child,
                                        compact: compact,
                                      ),
                                    )
                                  else
                                    Expanded(child: child),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const UserProfileThemeLoader(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileGroupMenu extends StatefulWidget {
  const _MobileGroupMenu({
    required this.preset,
    required this.menuScope,
    required this.activeMenu,
    this.slide = false,
  });

  final WorkspaceThemePreset preset;
  final WorkspaceMenuScope menuScope;
  final String? activeMenu;
  final bool slide;

  @override
  State<_MobileGroupMenu> createState() => _MobileGroupMenuState();
}

class _MobileGroupMenuState extends State<_MobileGroupMenu> {
  late Future<List<NavigationMenuGroup>> _menus;

  @override
  void initState() {
    super.initState();
    _menus = NavigationMenuRepository().getMenus();
  }

  List<NavigationMenuGroup> _visibleGroups(List<NavigationMenuGroup> groups) {
    final expectedScope = switch (widget.menuScope) {
      WorkspaceMenuScope.support => AppMenuScope.support,
      WorkspaceMenuScope.partner => AppMenuScope.partner,
      WorkspaceMenuScope.company => AppMenuScope.company,
    };
    return groups
        .map(
          (group) => NavigationMenuGroup(
            code: group.code,
            name: group.name,
            iconName: group.iconName,
            isExpandedDefault: group.isExpandedDefault,
            items: group.items.where((item) {
              final spec = AppMenuRouteRegistry.byMenuCode(item.code);
              return spec != null &&
                  (spec.scope == expectedScope ||
                      spec.scope == AppMenuScope.shared);
            }).toList(),
          ),
        )
        .where((group) => group.items.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Button/Style menu already exposes its menu cards; do not show a
    // redundant hamburger trigger. Slide menu keeps the trigger normally.
    if (widget.slide) {
      return Builder(
        builder: (context) => IconButton(
          tooltip: 'เมนู',
          iconSize: 32,
          padding: const EdgeInsets.all(8),
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: Icon(Icons.menu_rounded, color: widget.preset.primary),
        ),
      );
    }
    return FutureBuilder<List<NavigationMenuGroup>>(
      future: _menus,
      builder: (context, snapshot) {
        final groups = snapshot.data == null
            ? const <NavigationMenuGroup>[]
            : _visibleGroups(snapshot.data!);
        return PopupMenuButton<String>(
          tooltip: 'เมนู',
          enabled: snapshot.hasData,
          color: widget.preset.surface,
          onSelected: (code) async {
            if (code == '__all_groups__') {
              mobileSelectedMenuGroup.value = null;
              return;
            }
            if (code == '__logout__') {
              await appAuthController.logout();
              if (context.mounted) context.goNamed(RouteNames.login);
              return;
            }
            mobileSelectedMenuGroup.value = code;
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: '__all_groups__',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.apps_outlined,
                  color: widget.preset.primary,
                ),
                title: Text(
                  'แสดงทุกกลุ่มเมนู',
                  style: TextStyle(color: widget.preset.textPrimary),
                ),
              ),
            ),
            const PopupMenuDivider(),
            ...groups.map(
              (group) => PopupMenuItem<String>(
                value: group.code,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _buttonMenuIcon(group.iconName),
                    color: widget.preset.primary,
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(color: widget.preset.textPrimary),
                  ),
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: '__logout__',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'ออกจากระบบ',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
          child: Icon(
            Icons.menu_rounded,
            size: 32,
            color: widget.preset.primary,
          ),
        );
      },
    );
  }

  Future<void> _showFavorites(BuildContext context) async {
    final favorites = await _userFavoriteRepository.getAll();
    if (!context.mounted) return;
    await _showItems(
      context,
      'รายการโปรด',
      favorites
          .map(
            (item) => _MobileMenuEntry(
              name: item.menuName,
              iconName: item.iconName,
              routeName: AppMenuRouteRegistry.byMenuCode(
                item.menuCode,
              )?.goRouteName,
            ),
          )
          .where((item) => item.routeName != null)
          .toList(),
    );
  }

  Future<void> _showGroup(BuildContext context, NavigationMenuGroup group) =>
      _showItems(
        context,
        group.name,
        group.items
            .map((item) {
              final spec = AppMenuRouteRegistry.byMenuCode(item.code);
              return _MobileMenuEntry(
                name: item.name,
                iconName: item.iconName,
                routeName: spec?.goRouteName,
              );
            })
            .where((item) => item.routeName != null)
            .toList(),
      );

  Future<void> _showItems(
    BuildContext context,
    String title,
    List<_MobileMenuEntry> items,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: widget.preset.surface,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: widget.preset.primary,
                    fontSize: LaooTypography.sectionTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'ปิด',
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: Icon(Icons.close, color: widget.preset.primary),
              ),
            ],
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(
                    _buttonMenuIcon(item.iconName),
                    color: widget.preset.primary,
                  ),
                  title: Text(item.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.goNamed(item.routeName!);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _MobileMenuEntry {
  const _MobileMenuEntry({
    required this.name,
    required this.iconName,
    required this.routeName,
  });

  final String name;
  final String? iconName;
  final String? routeName;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.preset, required this.buttonMenu});

  final WorkspaceThemePreset preset;
  final bool buttonMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: preset.surface,
        border: Border(bottom: BorderSide(color: preset.border)),
      ),
      child: Row(
        children: [
          if (buttonMenu) ...[
            SizedBox(
              width: 160,
              child: _BrandHeader(
                accent: preset.primary,
                preset: preset,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
          ],
          _TopBarAction(
            icon: Icons.home_outlined,
            label: 'หน้าแรก',
            color: Theme.of(context).colorScheme.primary,
            onPressed: () => context.goNamed(RouteNames.authenticatedHome),
          ),
          Container(width: 1, height: 34, color: preset.border),
          _TopBarAction(
            icon: Icons.logout_outlined,
            label: 'ออกจากระบบ',
            color: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              await appAuthController.logout();
              if (context.mounted) context.goNamed(RouteNames.login);
            },
          ),
          const Spacer(),
          _UserMenu(preset: preset),
        ],
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(112, LaooTypography.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const RoundedRectangleBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: LaooTypography.button,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/* Removed optional button-menu mode. Sidebar is the only navigation mode.
class _MenuModeButton extends StatelessWidget {
  const _MenuModeButton({required this.enabled, required this.preset});

  final bool enabled;
  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: enabled ? 'ใช้เมนูแบบ Sidebar' : 'ใช้เมนูแบบปุ่ม',
      onPressed: () => _saveWorkspaceMenuMode(!enabled),
      icon: Icon(
        enabled ? Icons.view_sidebar_outlined : Icons.dashboard_outlined,
        color: preset.primary,
      ),
    );
  }
}

class _ButtonMenuWorkspace extends StatefulWidget {
  const _ButtonMenuWorkspace({
    required this.menuScope,
    required this.preset,
    required this.activeMenu,
    required this.child,
    required this.compact,
  });

  final WorkspaceMenuScope menuScope;
  final WorkspaceThemePreset preset;
  final String? activeMenu;
  final Widget child;
  final bool compact;

  @override
  State<_ButtonMenuWorkspace> createState() => _ButtonMenuWorkspaceState();
}

class _ButtonMenuWorkspaceState extends State<_ButtonMenuWorkspace> {
  late Future<List<NavigationMenuGroup>> _menus;
  List<UserFavorite> _favorites = const [];
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _menus = NavigationMenuRepository().getMenus();
    _loadFavorites();
    if (widget.compact) {
      mobileSelectedMenuGroup.value = null;
      _setDefaultMobileGroup();
    }
  }

  Future<void> _setDefaultMobileGroup() async {
    final menuGroups = _visibleGroups(await _menus);
    if (!mounted || menuGroups.isEmpty || mobileSelectedMenuGroup.value != null) {
      return;
    }
    mobileSelectedMenuGroup.value = menuGroups.first.code;
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _userFavoriteRepository.getAll();
      if (mounted) setState(() => _favorites = favorites);
    } catch (_) {}
  }

  List<NavigationMenuGroup> _visibleGroups(List<NavigationMenuGroup> groups) {
    final expectedScope = switch (widget.menuScope) {
      WorkspaceMenuScope.support => AppMenuScope.support,
      WorkspaceMenuScope.partner => AppMenuScope.partner,
      WorkspaceMenuScope.company => AppMenuScope.company,
    };
    return groups
        .map(
          (group) => NavigationMenuGroup(
            code: group.code,
            name: group.name,
            iconName: group.iconName,
            isExpandedDefault: group.isExpandedDefault,
            items: group.items.where((item) {
              final spec = AppMenuRouteRegistry.byMenuCode(item.code);
              return spec != null &&
                  (spec.scope == expectedScope ||
                      spec.scope == AppMenuScope.shared);
            }).toList(),
          ),
        )
        .where((group) => group.items.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NavigationMenuGroup>>(
      future: _menus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _menus =
                  NavigationMenuRepository().getMenus(refresh: true)),
              icon: const Icon(Icons.refresh),
              label: const Text('โหลดเมนูใหม่'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: widget.preset.primary),
          );
        }

        final groups = _visibleGroups(snapshot.data!);
        if (groups.isEmpty) return widget.child;
        final selected = groups.any((g) => g.code == _selectedGroup)
            ? _selectedGroup
            : null;
        final group = selected == null
            ? null
            : groups.firstWhere((item) => item.code == selected);

        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            final groupWidth = narrow ? 170.0 : 220.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: groupWidth,
                        child: _groupButtons(context, groups, selected),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: widget.child),
                    ],
                  ),
                  if (group != null)
                    Positioned(
                      left: groupWidth,
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selectedGroup = null),
                              child: Container(
                                color: Colors.black.withValues(alpha: .10),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: _menuButtons(context, group),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _groupButtons(
    BuildContext context,
    List<NavigationMenuGroup> groups,
    String? selected,
  ) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: groups.map((group) {
          final active = group.code == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedGroup = group.code),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? widget.preset.primary.withValues(alpha: .12)
                      : Colors.transparent,
                  border: Border.all(
                    color: active ? widget.preset.primary : widget.preset.border,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_buttonMenuIcon(group.iconName),
                        size: 20, color: widget.preset.primary),
                    const SizedBox(width: 7),
                    Text(group.name,
                        style: TextStyle(
                          color: widget.preset.primary,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _menuButtons(BuildContext context, NavigationMenuGroup group) {
    final currentPath = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: widget.preset.primary.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: TextStyle(
                      color: widget.preset.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิดเมนูย่อย',
                  onPressed: () => setState(() => _selectedGroup = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: group.items.map((item) {
                final spec = AppMenuRouteRegistry.byMenuCode(item.code);
                if (spec == null) return const SizedBox.shrink();
                final active =
                    spec.path == currentPath || item.code == widget.activeMenu;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedGroup = null);
                    context.goNamed(spec.goRouteName);
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      color: active
                          ? widget.preset.primary.withValues(alpha: .10)
                          : Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: active
                            ? widget.preset.primary
                            : widget.preset.border,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SizedBox(
                      width: 180,
                      height: 92,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _buttonMenuIcon(item.iconName),
                            size: 30,
                            color: active
                                ? widget.preset.primary
                                : widget.preset.textPrimary,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            item.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? widget.preset.primary
                                  : widget.preset.textPrimary,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                );
              }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/

class _MenuModeButton extends StatelessWidget {
  const _MenuModeButton({required this.enabled, required this.preset});

  final bool enabled;
  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: enabled ? 'ใช้เมนูแบบ Slide' : 'ใช้เมนูแบบปุ่ม',
      onPressed: () => workspaceButtonMenu.value = !enabled,
      icon: Icon(
        enabled ? Icons.dashboard_outlined : Icons.view_sidebar_outlined,
        color: preset.primary,
      ),
    );
  }
}

class _ButtonMenuWorkspace extends StatefulWidget {
  const _ButtonMenuWorkspace({
    required this.menuScope,
    required this.preset,
    required this.activeMenu,
    required this.child,
    required this.compact,
  });

  final WorkspaceMenuScope menuScope;
  final WorkspaceThemePreset preset;
  final String? activeMenu;
  final Widget child;
  final bool compact;

  @override
  State<_ButtonMenuWorkspace> createState() => _ButtonMenuWorkspaceState();
}

class _ButtonMenuWorkspaceState extends State<_ButtonMenuWorkspace> {
  late Future<List<NavigationMenuGroup>> _menus;
  List<UserFavorite> _favorites = const [];
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _menus = NavigationMenuRepository().getMenus();
    _loadFavorites();
    if (widget.compact) {
      mobileSelectedMenuGroup.value = null;
      _setDefaultMobileGroup();
    }
  }

  Future<void> _setDefaultMobileGroup() async {
    final groups = _visibleGroups(await _menus);
    if (!mounted || groups.isEmpty) return;
    mobileSelectedMenuGroup.value = groups.first.code;
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _userFavoriteRepository.getAll();
      if (mounted) setState(() => _favorites = favorites);
    } catch (_) {}
  }

  List<NavigationMenuGroup> _visibleGroups(List<NavigationMenuGroup> groups) {
    final expectedScope = switch (widget.menuScope) {
      WorkspaceMenuScope.support => AppMenuScope.support,
      WorkspaceMenuScope.partner => AppMenuScope.partner,
      WorkspaceMenuScope.company => AppMenuScope.company,
    };
    return groups
        .map(
          (group) => NavigationMenuGroup(
            code: group.code,
            name: group.name,
            iconName: group.iconName,
            isExpandedDefault: group.isExpandedDefault,
            items: group.items.where((item) {
              final spec = AppMenuRouteRegistry.byMenuCode(item.code);
              return spec != null &&
                  (spec.scope == expectedScope ||
                      spec.scope == AppMenuScope.shared);
            }).toList(),
          ),
        )
        .where((group) => group.items.isNotEmpty)
        .toList();
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
                () =>
                    _menus = NavigationMenuRepository().getMenus(refresh: true),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('โหลดเมนูใหม่'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: widget.preset.primary),
          );
        }

        final groups = _visibleGroups(snapshot.data!);
        if (widget.compact &&
            widget.activeMenu != null &&
            widget.activeMenu != 'home') {
          return widget.child;
        }
        if (widget.compact) {
          return ValueListenableBuilder<String?>(
            valueListenable: mobileSelectedMenuGroup,
            builder: (context, selectedCode, _) {
              return _buildCompactMenu(context, groups, selectedCode);
            },
          );
        }
        final selected = groups.any((g) => g.code == _selectedGroup)
            ? _selectedGroup
            : null;
        final group = selected == null
            ? null
            : groups.firstWhere((item) => item.code == selected);
        return LayoutBuilder(
          builder: (context, constraints) {
            const menuWidth = 180.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: menuWidth,
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    color: widget.preset.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide.none,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.preset.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: groups.map((item) {
                            return Padding(
                              padding: EdgeInsets.zero,
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: Card(
                                  color: Colors.transparent,
                                  elevation: 0,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide.none,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: widget.preset.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x12000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _selectedGroup = item.code,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          const SizedBox(width: 14),
                                          SizedBox(
                                            width: 32,
                                            child: Center(
                                              child: Icon(
                                                _buttonMenuIcon(item.iconName),
                                                size: 26,
                                                color: widget.preset.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: group == null
                      ? widget.child
                      : _buildGroup(context, group),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompactMenu(
    BuildContext context,
    List<NavigationMenuGroup> groups,
    String? selectedCode,
  ) {
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_favorites.isNotEmpty) ...[
                  _buildMobileFavorites(context),
                  const SizedBox(height: 14),
                ],
                _buildCompactGroupSelector(context, groups, selectedCode),
                if (selectedCode != null) ...[
                  const SizedBox(height: 14),
                  ...groups
                      .where(
                        (group) =>
                            group.code.trim().toUpperCase() ==
                            selectedCode.trim().toUpperCase(),
                      )
                      .map(
                        (group) =>
                            _buildCompactGroup(context, group, currentPath),
                      ),
                ],
              ],
            ),
          ),
        ),
        _buildCompactFooter(context, groups, selectedCode),
      ],
    );
  }

  Widget _buildCompactGroupSelector(
    BuildContext context,
    List<NavigationMenuGroup> groups,
    String? selectedCode,
  ) {
    final normalizedSelected = selectedCode?.trim().toUpperCase();
    return Card(
      color: widget.preset.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: widget.preset.primary.withValues(alpha: .18),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'กลุ่มเมนู',
              style: TextStyle(
                color: widget.preset.primary,
                fontSize: LaooTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groups.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 102,
                mainAxisExtent: 96,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final group = groups[index];
                final selected =
                    group.code.trim().toUpperCase() == normalizedSelected;
                return Card(
                  color: selected
                      ? widget.preset.primary.withValues(alpha: .12)
                      : widget.preset.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 3,
                  shadowColor: widget.preset.primary.withValues(alpha: .16),
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => mobileSelectedMenuGroup.value = group.code,
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _buttonMenuIcon(group.iconName),
                                  size: 30,
                                  color: widget.preset.primary,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  group.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: widget.preset.textPrimary,
                                    fontSize: LaooTypography.bodySmall,
                                    height: 1.15,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (selected)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 5,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: widget.preset.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactGroup(
    BuildContext context,
    NavigationMenuGroup group,
    String currentPath,
  ) {
    final items = group.items
        .where((item) => AppMenuRouteRegistry.byMenuCode(item.code) != null)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      color: widget.preset.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: widget.preset.primary.withValues(alpha: .18),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: TextStyle(
                color: widget.preset.primary,
                fontSize: LaooTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 102,
                mainAxisExtent: 96,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final spec = AppMenuRouteRegistry.byMenuCode(item.code)!;
                final active =
                    spec.path == currentPath || item.code == widget.activeMenu;
                return Card(
                  color: active
                      ? widget.preset.primary.withValues(alpha: .12)
                      : widget.preset.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 3,
                  shadowColor: widget.preset.primary.withValues(alpha: .16),
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => context.goNamed(spec.goRouteName),
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _buttonMenuIcon(item.iconName),
                                  size: 30,
                                  color: widget.preset.primary,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: widget.preset.textPrimary,
                                    fontSize: LaooTypography.bodySmall,
                                    height: 1.15,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (active)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 5,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: widget.preset.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFooter(
    BuildContext context,
    List<NavigationMenuGroup> groups,
    String? selectedCode,
  ) {
    final foreground = widget.preset.primary;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: widget.preset.surface,
          boxShadow: [
            BoxShadow(
              color: widget.preset.primary.withValues(alpha: .16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _CompactFooterButton(
                icon: Icons.apps_outlined,
                label: 'กลับหน้าแรก',
                color: foreground,
                onPressed: () =>
                    _showCompactGroupPicker(context, groups, selectedCode),
              ),
            ),
            Container(width: 1, height: 36, color: widget.preset.border),
            Expanded(
              child: _CompactFooterButton(
                icon: Icons.home_rounded,
                label: 'กลับหน้าแรก',
                color: foreground,
                onPressed: () => context.goNamed(RouteNames.authenticatedHome),
              ),
            ),
            Container(width: 1, height: 36, color: widget.preset.border),
            Expanded(
              child: _CompactFooterButton(
                icon: Icons.logout_rounded,
                label: 'ออกจากระบบ',
                color: foreground,
                onPressed: () async {
                  await appAuthController.logout();
                  if (context.mounted) context.goNamed(RouteNames.login);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompactGroupPicker(
    BuildContext context,
    List<NavigationMenuGroup> groups,
    String? selectedCode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: widget.preset.surface,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListTile(
            leading: Icon(Icons.apps_outlined, color: widget.preset.primary),
            title: Text(
              'แสดงทุกกลุ่มเมนู',
              style: TextStyle(color: widget.preset.textPrimary),
            ),
            selected: selectedCode == null,
            selectedColor: widget.preset.primary,
            onTap: () {
              mobileSelectedMenuGroup.value = null;
              Navigator.of(sheetContext).pop();
            },
          ),
          const Divider(),
          ...groups.map(
            (group) => ListTile(
              leading: Icon(
                _buttonMenuIcon(group.iconName),
                color: widget.preset.primary,
              ),
              title: Text(
                group.name,
                style: TextStyle(color: widget.preset.textPrimary),
              ),
              selected:
                  group.code.trim().toUpperCase() ==
                  selectedCode?.trim().toUpperCase(),
              selectedColor: widget.preset.primary,
              onTap: () {
                mobileSelectedMenuGroup.value = group.code;
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFavorites(BuildContext context) {
    final favorites = _favorites
        .where(
          (item) =>
              AppMenuRouteRegistry.byMenuCode(
                item.menuCode.trim().toUpperCase(),
              ) !=
              null,
        )
        .toList();
    if (favorites.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      color: widget.preset.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: widget.preset.primary.withValues(alpha: .18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'เมนูลัด',
              style: TextStyle(
                color: widget.preset.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 10,
              children: favorites.map((item) {
                return SizedBox.square(
                  dimension: 90,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: widget.preset.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 3,
                    shadowColor: widget.preset.primary.withValues(alpha: .16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () => _openFavorite(context, item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _buttonMenuIcon(item.iconName),
                              size: 26,
                              color: widget.preset.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.menuName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: widget.preset.textPrimary,
                                fontSize: 11,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _openFavorite(BuildContext context, UserFavorite item) {
    final spec = AppMenuRouteRegistry.byMenuCode(
      item.menuCode.trim().toUpperCase(),
    );
    if (spec != null) {
      // Use the registered path so the button works even when the route is
      // rendered inside the mobile button-menu workspace.
      context.go(spec.path);
      return;
    }

    final path = item.routePath?.trim();
    if (path != null && path.isNotEmpty) context.go(path);
  }

  Widget _buildGroup(BuildContext context, NavigationMenuGroup group) {
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    return Card(
      color: widget.preset.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      margin: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: widget.preset.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.items.map((item) {
                    final spec = AppMenuRouteRegistry.byMenuCode(item.code);
                    if (spec == null) return const SizedBox.shrink();
                    final active =
                        spec.path == currentPath ||
                        item.code == widget.activeMenu;
                    return SizedBox.square(
                      dimension: 100,
                      child: Card(
                        color: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide.none,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: active
                                  ? [
                                      widget.preset.primary.withValues(
                                        alpha: .16,
                                      ),
                                      widget.preset.primary.withValues(
                                        alpha: .07,
                                      ),
                                    ]
                                  : const [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFFFFFFF),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => context.goNamed(spec.goRouteName),
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _buttonMenuIcon(item.iconName),
                                  size: 30,
                                  color: widget.preset.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _buttonMenuIcon(String? name) => switch (name) {
  'home' => Icons.home_outlined,
  'people' => Icons.people_outline,
  'settings' => Icons.settings_outlined,
  'account_tree' => Icons.account_tree_outlined,
  'apartment' => Icons.apartment_outlined,
  'meeting_room' => Icons.meeting_room_outlined,
  _ => Icons.apps_outlined,
};

class _CompactFooterButton extends StatelessWidget {
  const _CompactFooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  String get _displayLabel => switch (icon) {
    Icons.palette_outlined => 'เลือกสี',
    Icons.apps_outlined => 'เมนู',
    Icons.home_rounded => 'กลับหน้าแรก',
    Icons.logout_rounded => 'ออกจากระบบ',
    _ => label,
  };

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteWorkspaceBar extends StatefulWidget {
  const _FavoriteWorkspaceBar();

  @override
  State<_FavoriteWorkspaceBar> createState() => _FavoriteWorkspaceBarState();
}

class _FavoriteWorkspaceBarState extends State<_FavoriteWorkspaceBar> {
  final _repository = UserFavoriteRepository();
  List<UserFavorite> _favorites = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    supportFavoriteRefresh.addListener(_reload);
    workspaceButtonMenu.addListener(_refreshMenuStyle);
    _load();
  }

  @override
  void dispose() {
    supportFavoriteRefresh.removeListener(_reload);
    workspaceButtonMenu.removeListener(_refreshMenuStyle);
    super.dispose();
  }

  void _reload() => _load();

  void _refreshMenuStyle() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repository.getAll(),
        NavigationMenuRepository().getMenus(),
      ]);
      final favorites = results[0] as List<UserFavorite>;
      final menus = results[1] as List<NavigationMenuGroup>;
      final visibleCodes = menus
          .expand((group) => group.items)
          .map((item) => item.code.trim().toUpperCase())
          .toSet();
      final visibleFavorites = favorites
          .where(
            (item) => visibleCodes.contains(item.menuCode.trim().toUpperCase()),
          )
          .toList();
      final revokedFavorites = favorites
          .where(
            (item) =>
                !visibleCodes.contains(item.menuCode.trim().toUpperCase()),
          )
          .toList();
      for (final item in revokedFavorites) {
        await _repository.remove(item.menuCode);
      }
      if (!mounted) return;
      setState(() {
        _favorites = visibleFavorites;
        _loading = false;
      });
      supportFavoritePages.value = visibleFavorites
          .map((e) => e.menuCode)
          .toSet();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String? name) => switch (name) {
    'home' => Icons.home_outlined,
    'people' => Icons.people_outline,
    'settings' => Icons.settings_outlined,
    'account_tree' => Icons.account_tree_outlined,
    'apartment' => Icons.apartment_outlined,
    _ => Icons.star_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading || _favorites.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final buttonStyle = workspaceButtonMenu.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'รายการโปรด',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            ..._favorites.map((item) {
              final spec = AppMenuRouteRegistry.byMenuCode(item.menuCode);
              final favoriteIndex = _favorites.indexOf(item);
              return Padding(
                padding: EdgeInsets.zero,
                child: buttonStyle
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: spec == null
                                ? null
                                : () => context.goNamed(spec.goRouteName),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _icon(item.iconName),
                                    size: 24,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.menuName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (favoriteIndex < _favorites.length - 1)
                            Container(
                              width: 1,
                              height: 32,
                              color: accent.withValues(alpha: .25),
                            ),
                        ],
                      )
                    : InkWell(
                        onTap: spec == null
                            ? null
                            : () => context.goNamed(spec.goRouteName),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.menuName, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent)),
                              if (favoriteIndex < _favorites.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('|', style: TextStyle(color: accent.withValues(alpha: .55))),
                                ),
                            ],
                          ),
                        ),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'ออกจากระบบ',
      onPressed: () async {
        await appAuthController.logout();
        if (context.mounted) {
          context.goNamed(RouteNames.login);
        }
      },
      icon: Icon(Icons.logout_outlined, color: color),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({this.compact = false, required this.preset});

  final bool compact;
  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final accent = preset.surface.computeLuminance() < 0.45
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: 'เลือก Theme',
      onPressed: () => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ThemePickerDialog(),
      ),
      icon: Icon(Icons.palette_outlined, color: accent),
    );
  }
}

class _ThemePickerDialog extends StatefulWidget {
  const _ThemePickerDialog();

  @override
  State<_ThemePickerDialog> createState() => _ThemePickerDialogState();
}

class _ThemePickerDialogState extends State<_ThemePickerDialog> {
  late WorkspaceThemePreset _original;
  late WorkspaceThemePreset _preview;
  String _group = 'Hybrid Dark Menu';
  bool _committed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _original = workspaceThemeController.value;
    _preview = _original;
    _group = _original.group;
  }

  void _select(WorkspaceThemePreset preset) {
    setState(() => _preview = preset);
    workspaceThemeController.value = preset;
  }

  void _cancel() {
    if (_saving) return;

    _committed = true;
    workspaceThemeController.value = _original;
    Navigator.of(context).pop();
  }

  Future<void> _apply() async {
    if (_saving) return;

    setState(() => _saving = true);
    _committed = true;

    try {
      await saveUserProfileTheme(_preview.code);
      await workspaceThemeController.save(_preview);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      _committed = false;
      if (!mounted) return;

      setState(() => _saving = false);
      showTimedSnackBar(
        context,
        message: 'ไม่สามารถบันทึก Theme ที่เลือกได้',
        error: true,
      );
    }
  }

  @override
  void dispose() {
    if (!_committed) {
      workspaceThemeController.value = _original;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final items = workspaceThemePresets
        .where((item) => item.group == _group)
        .toList();

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 40,
        vertical: mobile ? 16 : 24,
      ),
      title: const Text('เลือก Theme'),
      content: SizedBox(
        width: mobile ? double.infinity : 760,
        height: mobile ? MediaQuery.sizeOf(context).height * .68 : 500,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Hybrid Dark Menu',
                    label: Text('Hybrid'),
                  ),
                  ButtonSegment(value: 'White Menu', label: Text('White Menu')),
                  ButtonSegment(value: 'Light', label: Text('Light')),
                  ButtonSegment(value: 'Soft Dark', label: Text('Soft Dark')),
                ],
                selected: {_group},
                onSelectionChanged: (value) =>
                    setState(() => _group = value.first),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: mobile
                    ? const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 110,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      )
                    : const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisExtent: 118,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = item.code == _preview.code;
                  return InkWell(
                    onTap: () => _select(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? item.primary : item.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: item.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.code.substring(5),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: item.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _ThemeSwatch(color: item.sidebarBackground),
                              _ThemeSwatch(color: item.primary),
                              _ThemeSwatch(color: item.background),
                              _ThemeSwatch(color: item.surface),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: const Text('ใช้ Theme นี้'),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 16,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}

class _CompactUserMenu extends StatelessWidget {
  const _CompactUserMenu({required this.preset});

  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final accent = preset.surface.computeLuminance() < 0.45
        ? Colors.white
        : Theme.of(context).colorScheme.primary;

    return PopupMenuButton<String>(
      tooltip: 'ผู้ใช้งาน',
      onSelected: (value) async {
        if (value == 'profile') {
          final saved = await showUserProfileDialog(context);
          if (saved && context.mounted) showUserProfileSavedAlert(context);
          return;
        }
        if (value == 'logout') {
          await appAuthController.logout();
          if (context.mounted) {
            context.goNamed(RouteNames.login);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Text('ข้อมูลส่วนตัว', style: TextStyle(color: accent)),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Text('ออกจากระบบ', style: TextStyle(color: accent)),
        ),
      ],
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable: userProfileAvatarNotifier,
        builder: (_, image, _) => CircleAvatar(
          radius: 16,
          backgroundColor: accent.withValues(alpha: 0.12),
          backgroundImage: image == null ? null : MemoryImage(image),
          child: image == null
              ? Icon(Icons.person_outline, size: 18, color: accent)
              : null,
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.preset});

  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final darkSurface = preset.surface.computeLuminance() < 0.45;
    final accent = darkSurface
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    final foreground = darkSurface ? Colors.white : preset.textPrimary;
    final secondary = darkSurface
        ? Colors.white.withValues(alpha: 0.68)
        : preset.textSecondary;
    final session = appAuthController.session;
    final userName = session?.username ?? session?.displayName ?? '-';
    final userContext = session?.displayName ?? session?.userType ?? '-';

    return PopupMenuButton<String>(
      tooltip: 'เมนูผู้ใช้งาน',
      onSelected: (value) async {
        if (value == 'profile') {
          final saved = await showUserProfileDialog(context);
          if (saved && context.mounted) showUserProfileSavedAlert(context);
          return;
        }
        if (value == 'logout') {
          await appAuthController.logout();
          if (context.mounted) {
            context.goNamed(RouteNames.login);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Text('ข้อมูลส่วนตัว', style: TextStyle(color: foreground)),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Text('ออกจากระบบ', style: TextStyle(color: foreground)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: preset.surface,
          border: Border.all(color: preset.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<Uint8List?>(
              valueListenable: userProfileAvatarNotifier,
              builder: (_, image, _) => CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.12),
                backgroundImage: image == null ? null : MemoryImage(image),
                child: image == null
                    ? Icon(Icons.person_outline, size: 18, color: accent)
                    : null,
              ),
            ),
            const SizedBox(width: 9),
            ValueListenableBuilder<String?>(
              valueListenable: userProfileIntroductionNotifier,
              builder: (_, introduction, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: LaooTypography.userName,
                      fontWeight: LaooTypography.strongWeight,
                      color: foreground,
                    ),
                  ),
                  Text(
                    userContext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LaooTypography.userContext,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: foreground,
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.activeMenu,
    required this.preset,
    required this.menuScope,
  });

  final String? activeMenu;
  final WorkspaceThemePreset preset;
  final WorkspaceMenuScope menuScope;

  @override
  Widget build(BuildContext context) {
    final darkMenu = preset.sidebarBackground.computeLuminance() < 0.45;
    final itemForeground = darkMenu ? const Color(0xFFE5E7EB) : Colors.black87;
    final selectedForeground = darkMenu ? Colors.white : preset.primary;

    return _ApiRoleScopedSidebar(
      key: ValueKey(activeMenu),
      menuScope: menuScope,
      preset: preset,
      itemForeground: itemForeground,
      selectedForeground: selectedForeground,
    );
  }
}

class _ApiRoleScopedSidebar extends StatefulWidget {
  const _ApiRoleScopedSidebar({
    super.key,
    required this.menuScope,
    required this.preset,
    required this.itemForeground,
    required this.selectedForeground,
  });

  final WorkspaceMenuScope menuScope;
  final WorkspaceThemePreset preset;
  final Color itemForeground;
  final Color selectedForeground;

  @override
  State<_ApiRoleScopedSidebar> createState() => _ApiRoleScopedSidebarState();
}

class _ApiRoleScopedSidebarState extends State<_ApiRoleScopedSidebar> {
  late final NavigationMenuRepository _repository;
  late Future<List<NavigationMenuGroup>> _menus;

  @override
  void initState() {
    super.initState();
    _repository = NavigationMenuRepository();
    _menus = _repository.getMenus();
  }

  void _reload() {
    setState(() => _menus = _repository.getMenus(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NavigationMenuGroup>>(
      future: _menus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final unauthorized =
              snapshot.error is ApiException &&
              (snapshot.error! as ApiException).isUnauthorized;
          return _buildLoadState(
            context,
            message: unauthorized
                ? 'Session หมดอายุ กรุณาเข้าสู่ระบบใหม่'
                : 'ไม่สามารถโหลดเมนูตามสิทธิ์ได้',
            onRetry: unauthorized ? null : _reload,
            onLogin: unauthorized
                ? () async {
                    await appAuthController.logout();
                    if (context.mounted) context.goNamed(RouteNames.login);
                  }
                : null,
          );
        }
        if (!snapshot.hasData) {
          return _buildLoadState(context);
        }
        return _buildSidebar(context, snapshot.data!);
      },
    );
  }

  Widget _buildSidebar(BuildContext context, List<NavigationMenuGroup> groups) {
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    final expectedScope = switch (widget.menuScope) {
      WorkspaceMenuScope.support => AppMenuScope.support,
      WorkspaceMenuScope.partner => AppMenuScope.partner,
      WorkspaceMenuScope.company => AppMenuScope.company,
    };
    final menuGroups = groups
        .map(
          (group) => NavigationMenuGroup(
            code: group.code,
            name: group.name,
            iconName: group.iconName,
            isExpandedDefault: group.isExpandedDefault,
            items: group.items.where((item) {
              final spec = AppMenuRouteRegistry.byMenuCode(item.code);
              return spec != null &&
                  (spec.scope == expectedScope ||
                      spec.scope == AppMenuScope.shared);
            }).toList(),
          ),
        )
        .where((group) => group.items.isNotEmpty)
        .toList();
    final homeRoute = widget.menuScope == WorkspaceMenuScope.support
        ? RouteNames.supportHome
        : RouteNames.authenticatedHome;
    final homePath = widget.menuScope == WorkspaceMenuScope.support
        ? RoutePaths.supportHome
        : RoutePaths.authenticatedHome;
    return Material(
      color: widget.preset.sidebarBackground,
      child: Column(
        children: [
          _BrandHeader(accent: widget.preset.primary, preset: widget.preset),
          Divider(height: 1, color: widget.preset.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              children: [
                _MenuItem(
                  label: 'หน้าหลัก',
                  icon: Icons.home_outlined,
                  selected: currentPath == homePath,
                  accent: widget.itemForeground,
                  selectedAccent: widget.preset.primary,
                  selectedForeground: widget.selectedForeground,
                  onTap: () => context.goNamed(homeRoute),
                ),
                const SizedBox(height: 2),
                ...menuGroups
                    .where((group) => group.items.isNotEmpty)
                    .map(
                      (group) => _MenuGroup(
                        title: group.name,
                        accent: widget.preset.primary,
                        initiallyExpanded:
                            group.isExpandedDefault ||
                            group.items.any((item) {
                              final spec = AppMenuRouteRegistry.byMenuCode(
                                item.code,
                              );
                              return spec?.path == currentPath;
                            }),
                        children: group.items.map((item) {
                          final spec = AppMenuRouteRegistry.byMenuCode(
                            item.code,
                          );
                          return _MenuItem(
                            label: item.name,
                            icon: _iconFor(item.iconName),
                            selected: spec?.path == currentPath,
                            accent: widget.itemForeground,
                            selectedAccent: widget.preset.primary,
                            selectedForeground: widget.selectedForeground,
                            onTap: spec == null
                                ? null
                                : () => context.goNamed(spec.goRouteName),
                          );
                        }).toList(),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadState(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
    Future<void> Function()? onLogin,
  }) {
    return Material(
      color: widget.preset.sidebarBackground,
      child: Column(
        children: [
          _BrandHeader(accent: widget.preset.primary, preset: widget.preset),
          Divider(height: 1, color: widget.preset.border),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: message == null
                    ? CircularProgressIndicator(color: widget.preset.primary)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: widget.itemForeground,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: widget.itemForeground),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: onLogin == null
                                ? onRetry
                                : () => onLogin(),
                            child: Text(
                              onLogin == null ? 'ลองใหม่' : 'เข้าสู่ระบบใหม่',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? name) {
    return switch (name) {
      'apartment' => Icons.apartment_outlined,
      'account_tree' => Icons.account_tree_outlined,
      'people' => Icons.people_outline,
      'inventory_2' => Icons.inventory_2_outlined,
      'sell' => Icons.sell_outlined,
      'settings' => Icons.settings_outlined,
      'developer_mode' => Icons.developer_mode_outlined,
      _ => Icons.menu_outlined,
    };
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.title,
    required this.accent,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final Color accent;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>('support-menu-$title'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: EdgeInsets.zero,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        minTileHeight: 30,
        iconColor: accent,
        collapsedIconColor: accent,
        title: Text(
          title,
          style: TextStyle(
            fontSize: LaooTypography.menuGroup,
            fontWeight: LaooTypography.normalWeight,
            color: accent,
            height: 1,
          ),
        ),
        children: children,
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.accent,
    required this.preset,
    this.lightSurface = false,
    this.compact = false,
    this.onTap,
  });

  final Color accent;
  final WorkspaceThemePreset preset;
  final bool lightSurface;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final darkSidebar =
        !lightSurface && preset.sidebarBackground.computeLuminance() < 0.45;
    final titleColor = compact
        ? preset.primary
        : darkSidebar
        ? Colors.white
        : preset.primary;
    final secondaryColor = compact
        ? preset.primary.withValues(alpha: 0.72)
        : darkSidebar
        ? Colors.white.withValues(alpha: 0.72)
        : preset.textSecondary;
    final iconBackground = compact
        ? preset.primary
        : darkSidebar
        ? Color.lerp(preset.primary, Colors.white, 0.10)!
        : preset.primary;
    final iconColor = compact ? preset.surface : Colors.white;

    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) {
        final setup = companySetupController.current;
        final systemTitle = setup?.titleHeader.trim().isNotEmpty == true
            ? setup!.titleHeader.trim()
            : 'Laoo Solutions';
        final configuredVersion = setup?.versionId.trim() ?? '';
        final version = configuredVersion.isNotEmpty
            ? configuredVersion
            : (compact ? '1.0.0' : '');

        return GestureDetector(
          onTap: onTap ??
              () => context.goNamed(
                    appAuthController.isLaooSupport
                        ? RouteNames.supportHome
                        : RouteNames.authenticatedHome,
                  ),
          child: SizedBox(
            height: compact ? 64 : 72,
            child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 16),
            child: Row(
              children: [
                if (compact)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'L',
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  )
                else
                  ValueListenableBuilder<Uint8List?>(
                    valueListenable: userProfileAvatarNotifier,
                    builder: (_, image, _) => Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(9),
                        image: image == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(image),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: image == null
                          ? Icon(
                              Icons.home_work_outlined,
                              size: 19,
                              color: iconColor,
                            )
                          : null,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        systemTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact
                              ? LaooTypography.mobileSystemTitle
                              : LaooTypography.systemTitle,
                          fontWeight: LaooTypography.pageTitleWeight,
                          color: titleColor,
                          height: 1.08,
                        ),
                      ),
                      if (version.isNotEmpty) ...[
                        SizedBox(height: compact ? 2 : 4),
                        Text(
                          'Version $version',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact
                                ? LaooTypography.mobileSystemVersion
                                : LaooTypography.systemVersion,
                            fontWeight: FontWeight.w500,
                            color: secondaryColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    this.selectedAccent,
    this.selectedForeground,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final Color? selectedAccent;
  final Color? selectedForeground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selectionColor = selectedAccent ?? accent;
    final foreground = selected ? (selectedForeground ?? accent) : accent;

    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: selected
            ? selectionColor.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: foreground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: LaooTypography.menuItem,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
