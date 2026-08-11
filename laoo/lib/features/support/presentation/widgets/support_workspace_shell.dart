import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_menu_route_registry.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';

final ValueNotifier<Set<String>> supportFavoritePages =
    ValueNotifier<Set<String>>(<String>{});

enum WorkspaceMenuScope { support, partner, company }

class WorkspacePageTitle extends StatelessWidget {
  const WorkspacePageTitle({super.key, required this.title, this.favoriteKey});

  final String title;
  final String? favoriteKey;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final key = favoriteKey;

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
              final selected = favorites.contains(key);
              return IconButton(
                tooltip: selected
                    ? 'นำออกจากเมนูลัดของฉัน'
                    : 'เพิ่มหน้านี้เป็นเมนูลัดของฉัน',
                onPressed: () {
                  final next = <String>{...favorites};
                  selected ? next.remove(key) : next.add(key);
                  supportFavoritePages.value = next;
                },
                icon: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: accent,
                ),
              );
            },
          ),
        ],
      ],
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
  });

  final String pageTitle;
  final String? activeMenu;
  final Widget child;
  final WorkspaceMenuScope menuScope;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) {
        final compact = MediaQuery.sizeOf(context).width < 900;
        final baseTheme = preset.toThemeData();
        // Theme changes the navigation chrome and accent colors. The content
        // workspace is intentionally white for every STYLE for readability.
        final workspaceTheme = baseTheme.copyWith(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          cardColor: Colors.white,
          colorScheme: baseTheme.colorScheme.copyWith(
            brightness: Brightness.light,
            surface: Colors.white,
            onSurface: Colors.black87,
            onSurfaceVariant: Colors.black54,
          ),
          textTheme: baseTheme.textTheme.apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
          ),
          cardTheme: baseTheme.cardTheme.copyWith(
            color: Colors.white,
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
              backgroundColor: Colors.white,
              drawer: compact
                  ? Drawer(
                      backgroundColor: preset.sidebarBackground,
                      child: _Sidebar(
                        activeMenu: activeMenu,
                        preset: preset,
                        menuScope: menuScope,
                      ),
                    )
                  : null,
              appBar: compact
                  ? AppBar(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      titleSpacing: 0,
                      actions: [
                        _ThemeButton(compact: true, preset: preset),
                        _FavoritesButton(compact: true, preset: preset),
                        IconButton(
                          tooltip: 'กลับหน้าหลัก',
                          onPressed: () =>
                              context.goNamed(RouteNames.authenticatedHome),
                          icon: Icon(
                            Icons.home_outlined,
                            color: preset.primary,
                          ),
                        ),
                        _LogoutButton(color: preset.primary),
                        _CompactUserMenu(preset: preset),
                        const SizedBox(width: 8),
                      ],
                    )
                  : null,
              body: SafeArea(
                child: Row(
                  children: [
                    if (!compact)
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
                          if (!compact) _TopBar(preset: preset),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.preset});

  final WorkspaceThemePreset preset;

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
          IconButton(
            tooltip: 'กลับหน้าหลัก',
            onPressed: () => context.goNamed(RouteNames.authenticatedHome),
            icon: Icon(
              Icons.home_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          _LogoutButton(color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          _ThemeButton(preset: preset),
          const SizedBox(width: 4),
          _FavoritesButton(preset: preset),
          const Spacer(),
          _UserMenu(preset: preset),
        ],
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

class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton({this.compact = false, required this.preset});

  final bool compact;
  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: supportFavoritePages,
      builder: (context, favorites, _) {
        return PopupMenuButton<String>(
          tooltip: 'เมนูลัดของฉัน',
          onSelected: (value) {
            if (value == 'Partner') {
              context.goNamed(RouteNames.partner);
            } else if (value == 'Company Setup') {
              context.goNamed(RouteNames.companySetup);
            }
          },
          itemBuilder: (context) {
            if (favorites.isEmpty) {
              return const [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('ยังไม่มีเมนูลัด'),
                ),
              ];
            }
            return favorites
                .map(
                  (item) => PopupMenuItem<String>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(item),
                      ],
                    ),
                  ),
                )
                .toList();
          },
          child: compact
              ? Icon(Icons.star_outline_rounded, color: accent)
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: preset.surface,
                    border: Border.all(color: preset.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_outline_rounded, size: 18, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Favorite',
                        style: TextStyle(
                          color: preset.surface.computeLuminance() < 0.45
                              ? Colors.white
                              : preset.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
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
      await workspaceThemeController.save(_preview);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      _committed = false;
      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถบันทึก Theme ที่เลือกได้')),
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
    final items = workspaceThemePresets
        .where((item) => item.group == _group)
        .toList();

    return AlertDialog(
      title: const Text('เลือก Theme'),
      content: SizedBox(
        width: 760,
        height: 500,
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Hybrid Dark Menu', label: Text('Hybrid')),
                ButtonSegment(value: 'White Menu', label: Text('White Menu')),
                ButtonSegment(value: 'Light', label: Text('Light')),
                ButtonSegment(value: 'Soft Dark', label: Text('Soft Dark')),
              ],
              selected: {_group},
              onSelectionChanged: (value) =>
                  setState(() => _group = value.first),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
        if (value == 'logout') {
          await appAuthController.logout();
          if (context.mounted) {
            context.goNamed(RouteNames.login);
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ')),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: accent.withValues(alpha: 0.12),
        child: Icon(Icons.person_outline, size: 18, color: accent),
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
    final userName = session?.displayName ?? session?.username ?? '-';
    final userContext = session?.username ?? session?.userType ?? '-';

    return PopupMenuButton<String>(
      tooltip: 'เมนูผู้ใช้งาน',
      onSelected: (value) async {
        if (value == 'logout') {
          await appAuthController.logout();
          if (context.mounted) {
            context.goNamed(RouteNames.login);
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ')),
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
            CircleAvatar(
              radius: 16,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(Icons.person_outline, size: 18, color: accent),
            ),
            const SizedBox(width: 9),
            Column(
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
                  style: TextStyle(
                    fontSize: LaooTypography.userContext,
                    color: secondary,
                  ),
                ),
              ],
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
    final isWhiteMenu = preset.group == 'White Menu';
    final isLightColored = preset.group == 'Light';
    final isHybrid = preset.group == 'Hybrid Dark Menu';

    const blackSubmenuStyles = {
      'STYLE11',
      'STYLE14',
      'STYLE16',
      'STYLE17',
      'STYLE18',
      'STYLE19',
    };
    final useBlackSubmenu = blackSubmenuStyles.contains(
      preset.code.toUpperCase(),
    );

    final itemForeground = isWhiteMenu || useBlackSubmenu
        ? Colors.black87
        : isLightColored
        ? const Color(0xFFF7F8FA)
        : isHybrid
        ? const Color(0xFFE5E7EB)
        : const Color(0xFFE5E7EB);

    final selectedForeground = useBlackSubmenu
        ? Colors.black87
        : isWhiteMenu
        ? preset.primary
        : isLightColored
        ? Colors.white
        : isHybrid
        ? Colors.white
        : const Color(0xFFF9FAFB);

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
          return _buildLoadState(
            context,
            message: 'ไม่สามารถโหลดเมนูตามสิทธิ์ได้',
            onRetry: _reload,
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
              return spec != null && spec.scope == expectedScope;
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
                            onPressed: onRetry,
                            child: const Text('ลองใหม่'),
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
  const _BrandHeader({required this.accent, required this.preset});

  final Color accent;
  final WorkspaceThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final darkSidebar = preset.sidebarBackground.computeLuminance() < 0.45;
    final titleColor = darkSidebar ? Colors.white : preset.primary;
    final secondaryColor = darkSidebar
        ? Colors.white.withValues(alpha: 0.72)
        : preset.textSecondary;
    final iconBackground = darkSidebar
        ? Color.lerp(preset.primary, Colors.white, 0.10)!
        : preset.primary;

    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) {
        final setup = companySetupController.current;
        final systemTitle = setup?.titleHeader.trim().isNotEmpty == true
            ? setup!.titleHeader.trim()
            : 'Laoo Solutions';
        final version = setup?.versionId.trim() ?? '';

        return SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    size: 19,
                    color: Colors.white,
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
                          fontSize: LaooTypography.systemTitle,
                          fontWeight: LaooTypography.pageTitleWeight,
                          color: titleColor,
                          height: 1.08,
                        ),
                      ),
                      if (version.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Version $version',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: LaooTypography.systemVersion,
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
