import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/company_setup/company_setup_controller.dart';

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
              fontSize: LaooTypography.pageTitle,
              fontWeight: LaooTypography.pageTitleWeight,
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
        final isHybrid = preset.group == 'Hybrid Dark Menu';
        final baseTheme = preset.toThemeData();
        final workspaceTheme = isHybrid
            ? baseTheme.copyWith(
                scaffoldBackgroundColor: Colors.white,
                cardColor: Colors.white,
                colorScheme: baseTheme.colorScheme.copyWith(
                  surface: Colors.white,
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
              )
            : baseTheme;
        return Theme(
          data: workspaceTheme,
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: isHybrid ? Colors.white : preset.background,
              drawer: compact
                  ? Drawer(
                      backgroundColor: preset.sidebarBackground,
                      child: _Sidebar(activeMenu: activeMenu, preset: preset, menuScope: menuScope),
                    )
                  : null,
              appBar: compact
                  ? AppBar(
                      backgroundColor: preset.surface,
                      surfaceTintColor: preset.surface,
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
                        child: _Sidebar(activeMenu: activeMenu, preset: preset, menuScope: menuScope),
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
  const _Sidebar({required this.activeMenu, required this.preset, required this.menuScope});

  final String? activeMenu;
  final WorkspaceThemePreset preset;
  final WorkspaceMenuScope menuScope;

  @override
  Widget build(BuildContext context) {
    final accent = preset.primary;
    final isWhiteMenu = preset.group == 'White Menu';
    final isLightColored = preset.group == 'Light';
    final isHybrid = preset.group == 'Hybrid Dark Menu';

    final groupAccent = isWhiteMenu
        ? preset.primary
        : isLightColored
        ? (preset.sidebarBackground.computeLuminance() < 0.45
              ? Color.lerp(preset.sidebarText, preset.primary, 0.35)!
              : preset.primary)
        : preset.primary;

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

    if (menuScope != WorkspaceMenuScope.support) {
      return _RoleScopedSidebar(
        menuScope: menuScope,
        activeMenu: activeMenu,
        preset: preset,
        itemForeground: itemForeground,
        selectedForeground: selectedForeground,
      );
    }

    return Material(
      color: preset.sidebarBackground,
      child: Column(
        children: [
          _BrandHeader(accent: accent, preset: preset),
          Divider(height: 1, color: preset.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              children: [
                _MenuItem(
                  label: 'หน้าหลัก',
                  icon: Icons.home_outlined,
                  selected: activeMenu == 'home',
                  accent: itemForeground,
                  selectedAccent: accent,
                  selectedForeground: selectedForeground,
                  onTap: () => context.goNamed(RouteNames.supportHome),
                ),
                const SizedBox(height: 2),
                _MenuGroup(
                  title: 'จัดการองค์กร',
                  accent: groupAccent,
                  initiallyExpanded: const {
                    'partner',
                    'company', 'branch',
                  }.contains(activeMenu),
                  children: [
                    _MenuItem(
                      label: 'Partner',
                      icon: Icons.handshake_outlined,
                      selected: activeMenu == 'partner',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.partner),
                    ),
                    _MenuItem(
                      label: 'Company',
                      icon: Icons.apartment_outlined,
                      selected: activeMenu == 'company',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.company),
                    ),
                    _MenuItem(
                      label: 'Branch',
                      icon: Icons.account_tree_outlined,
                      selected: activeMenu == 'branch',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.branch),
                    ),
                  ],
                ),
                _MenuGroup(
                  title: 'จัดการผู้ใช้งาน',
                  accent: groupAccent,
                  initiallyExpanded: const {
                    'laooUser', 'partnerUser', 'companyUser',
                  }.contains(activeMenu),
                  children: [
                    _MenuItem(
                      label: 'Laoo User',
                      icon: Icons.support_agent_outlined,
                      selected: activeMenu == 'laooUser',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.laooUser),
                    ),
                    _MenuItem(
                      label: 'Partner User',
                      icon: Icons.person_outline,
                      selected: activeMenu == 'partnerUser',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.partnerUser),
                    ),
                    _MenuItem(
                      label: 'Company User',
                      icon: Icons.people_outline,
                      selected: activeMenu == 'companyUser',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.companyUser),
                    ),
                  ],
                ),
                _MenuGroup(
                  title: 'Module และสิทธิ์',
                  accent: groupAccent,
                  initiallyExpanded: const {'module', 'customerModule', 'permission'}.contains(activeMenu),
                  children: [
                    _MenuItem(label: 'Module', icon: Icons.widgets_outlined, selected: activeMenu == 'module', accent: itemForeground, selectedAccent: accent, selectedForeground: selectedForeground, onTap: () => context.goNamed(RouteNames.module)),
                    _MenuItem(label: 'Customer Module', icon: Icons.extension_outlined, selected: activeMenu == 'customerModule', accent: itemForeground, selectedAccent: accent, selectedForeground: selectedForeground, onTap: () => context.goNamed(RouteNames.customerModule)),
                    _MenuItem(label: 'Role / Permission', icon: Icons.admin_panel_settings_outlined, selected: activeMenu == 'permission', accent: itemForeground, selectedAccent: accent, selectedForeground: selectedForeground, onTap: () => context.goNamed(RouteNames.permission)),
                  ],
                ),
                _MenuGroup(
                  title: 'ตรวจสอบระบบ',
                  accent: groupAccent,
                  initiallyExpanded: activeMenu == 'audit',
                  children: [
                    _MenuItem(
                      label: 'Audit Log',
                      icon: Icons.receipt_long_outlined,
                      selected: activeMenu == 'audit',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.audit),
                    ),
                    _MenuItem(
                      label: 'Login Log',
                      icon: Icons.login_outlined,
                      selected: activeMenu == 'loginLog',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.loginLog),
                    ),
                  ],
                ),
                _MenuGroup(
                  title: 'ตั้งค่าระบบ',
                  accent: groupAccent,
                  initiallyExpanded: activeMenu == 'companySetup',
                  children: [
                    _MenuItem(
                      label: 'กำหนดค่าระบบ',
                      icon: Icons.settings_outlined,
                      selected: activeMenu == 'companySetup',
                      accent: itemForeground,
                      selectedAccent: accent,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(RouteNames.companySetup),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleScopedSidebar extends StatelessWidget {
  const _RoleScopedSidebar({
    required this.menuScope,
    required this.activeMenu,
    required this.preset,
    required this.itemForeground,
    required this.selectedForeground,
  });

  final WorkspaceMenuScope menuScope;
  final String? activeMenu;
  final WorkspaceThemePreset preset;
  final Color itemForeground;
  final Color selectedForeground;

  @override
  Widget build(BuildContext context) {
    final isPartner = menuScope == WorkspaceMenuScope.partner;
    return Material(
      color: preset.sidebarBackground,
      child: Column(
        children: [
          _BrandHeader(accent: preset.primary, preset: preset),
          Divider(height: 1, color: preset.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              children: [
                _MenuItem(
                  label: 'หน้าหลัก',
                  icon: Icons.home_outlined,
                  selected: activeMenu == 'home',
                  accent: itemForeground,
                  selectedAccent: preset.primary,
                  selectedForeground: selectedForeground,
                  onTap: () => context.goNamed(RouteNames.authenticatedHome),
                ),
                const SizedBox(height: 2),
                _MenuGroup(
                  title: isPartner ? 'จัดการบริษัท' : 'ระบบสินค้า',
                  accent: preset.primary,
                  initiallyExpanded: true,
                  children: isPartner
                      ? [
                          _MenuItem(label: 'ข้อมูลบริษัท', icon: Icons.apartment_outlined, selected: activeMenu == 'partnerCompanies', accent: itemForeground, selectedAccent: preset.primary, selectedForeground: selectedForeground, onTap: () => context.goNamed(RouteNames.partnerCompanies)),
                          _MenuItem(label: 'ข้อมูลสาขา', icon: Icons.account_tree_outlined, selected: activeMenu == 'partnerBranches', accent: itemForeground, selectedAccent: preset.primary, selectedForeground: selectedForeground, onTap: () => context.goNamed(RouteNames.partnerBranches)),
                        ]
                      : [
                          _MenuItem(label: 'ข้อมูลสินค้า', icon: Icons.inventory_2_outlined, selected: activeMenu == 'companyProducts', accent: itemForeground, selectedAccent: preset.primary, selectedForeground: selectedForeground, onTap: () => context.goNamed(RouteNames.companyProducts)),
                        ],
                ),
                _MenuGroup(
                  title: isPartner ? 'จัดการผู้ใช้งาน' : 'ระบบขาย',
                  accent: preset.primary,
                  initiallyExpanded: true,
                  children: [
                    _MenuItem(
                      label: isPartner ? 'ผู้ใช้งานบริษัท' : 'ข้อมูลลูกค้า',
                      icon: isPartner ? Icons.people_outline : Icons.people_alt_outlined,
                      selected: activeMenu == (isPartner ? 'partnerUsers' : 'companyCustomers'),
                      accent: itemForeground,
                      selectedAccent: preset.primary,
                      selectedForeground: selectedForeground,
                      onTap: () => context.goNamed(isPartner ? RouteNames.partnerUsers : RouteNames.companyCustomers),
                    ),
                  ],
                ),
              ],
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
