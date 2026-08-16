import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_menu_route_registry.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/favorites/user_favorite_repository.dart';
import '../../../../core/navigation/navigation_menu.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../profile/pages/user_profile_dialog.dart';

final ValueNotifier<Set<String>> supportFavoritePages =
    ValueNotifier<Set<String>>(<String>{});
final ValueNotifier<int> supportFavoriteRefresh = ValueNotifier<int>(0);
final UserFavoriteRepository _userFavoriteRepository = UserFavoriteRepository();

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
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
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
                      backgroundColor: preset.surface,
                      surfaceTintColor: Colors.transparent,
                      titleSpacing: 0,
                      actions: [
                        _ThemeButton(compact: true, preset: preset),
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
                child: Stack(
                  children: [
                    Row(
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
                              const _FavoriteWorkspaceBar(),
                              Expanded(child: child),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const UserProfileThemeLoader(),
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
          _ThemeButton(preset: preset),
          const Spacer(),
          _UserMenu(preset: preset),
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
  });

  final WorkspaceMenuScope menuScope;
  final WorkspaceThemePreset preset;
  final String? activeMenu;
  final Widget child;

  @override
  State<_ButtonMenuWorkspace> createState() => _ButtonMenuWorkspaceState();
}

class _ButtonMenuWorkspaceState extends State<_ButtonMenuWorkspace> {
  late Future<List<NavigationMenuGroup>> _menus;
  String? _selectedGroup;

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
    _load();
  }

  @override
  void dispose() {
    supportFavoriteRefresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

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
            ..._favorites.map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(_icon(item.iconName), size: 17, color: accent),
                  label: Text(item.menuName, overflow: TextOverflow.ellipsis),
                  onPressed: () {
                    final spec = AppMenuRouteRegistry.byMenuCode(item.menuCode);
                    if (spec != null) context.goNamed(spec.goRouteName);
                  },
                ),
              ),
            ),
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
                    introduction?.isNotEmpty == true
                        ? introduction!
                        : userContext,
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
                        ? const Icon(
                            Icons.home_work_outlined,
                            size: 19,
                            color: Colors.white,
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
