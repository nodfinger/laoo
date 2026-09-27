import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../role_group/data/role_group_repository.dart';
import '../../role_group/models/role_group.dart';
import '../data/menu_permission_repository.dart';
import '../models/menu_permission_row.dart';
import '../models/menu_permission_selection.dart';
import '../../../profile/data/user_profile_repository.dart';

class MenuPermissionPage extends StatefulWidget {
  const MenuPermissionPage({
    super.key,
    required this.scope,
    required this.activeMenu,
  });
  final String scope, activeMenu;
  @override
  State<MenuPermissionPage> createState() => _MenuPermissionPageState();
}

class _MenuPermissionPageState extends State<MenuPermissionPage> {
  static const double _menuColumnWidth = 430;
  static const double _permissionColumnWidth = 72;

  final _groups = RoleGroupRepository();
  final _permissions = MenuPermissionRepository();
  final _profile = UserProfileRepository();
  List<RoleGroup> _roleGroups = const [];
  List<MenuPermissionRow> _rows = const [];
  int? _selectedGroup;
  String? _selectedSystemLevel;
  String? _selectedMenuGroup;
  bool _loading = true, _saving = false;
  bool _canEdit = false, _canDelete = false;
  String? _message;
  bool _error = false;
  Timer? _alertTimer;
  bool _card = false;
  final Set<String> _collapsedMenuGroups = <String>{};

  @override
  void initState() {
    super.initState();
    _loadActions();
    _loadGroups();
    _loadDefaultViewMode();
  }

  Future<void> _loadDefaultViewMode() async {
    try {
      final profile = await _profile.get();
      if (mounted) {
        setState(
          () => _card =
              profile['defaultViewMode']?.toString().toUpperCase() == 'CARD',
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActions() async {
    try {
      final p = await _permissions.actions(widget.scope);
      if (mounted) {
        setState(() {
          _canEdit = p['edit'] == true;
          _canDelete = p['delete'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _groups.list(widget.scope);
      if (!mounted) return;
      setState(() {
        _roleGroups = groups.where((e) => e.isActive).toList();
        _selectedGroup = _roleGroups.isEmpty ? null : _roleGroups.first.id;
        _selectedMenuGroup = null;
      });
      if (_selectedGroup != null) await _loadRows();
    } catch (e) {
      _showError(_thai(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRows() async {
    final id = _selectedGroup;
    if (id == null) {
      setState(() => _rows = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await _permissions.list(widget.scope, id);
      if (mounted) {
        setState(() {
          _rows = rows;
          _selectedSystemLevel = null;
          _selectedMenuGroup = null;
          _collapsedMenuGroups
            ..clear()
            ..addAll(rows.map((row) => row.groupKey));
        });
      }
    } catch (e) {
      _showError(_thai(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final id = _selectedGroup;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await _permissions.save(widget.scope, id, _rows);
      _show('บันทึกสิทธิ์เมนูสำเร็จ');
    } catch (e) {
      _showError(_thai(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _clearAll() async {
    final id = _selectedGroup;
    if (id == null) return;
    final matchingGroups = _roleGroups.where((e) => e.id == id).toList();
    final groupName = matchingGroups.isEmpty ? '' : matchingGroups.first.name;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFFF4FAF7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.red, width: 1.5),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD3DC),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ยืนยันลบข้อมูลกลุ่มสิทธิ์',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC5D0),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'ต้องการลบ $groupName หรือไม่?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'ยกเลิก',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await _permissions.clear(widget.scope, id);
      if (mounted) {
        setState(
          () => _rows = _rows
              .map(
                (e) => e.copy(
                  view: false,
                  create: false,
                  edit: false,
                  delete: false,
                ),
              )
              .toList(),
        );
      }
      _notice('ลบสิทธิ์ทั้งหมดสำเร็จ');
    } catch (e) {
      _showError(_thai(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  void _show(String text) {
    _notice(text);
  }

  void _showError(String text) {
    _notice(text, error: true);
  }

  void _notice(String text, {bool error = false}) {
    _alertTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _message = text;
      _error = error;
    });
    _alertTimer = Timer(
      Duration(seconds: companySetupController.current?.timeAlert ?? 30),
      () {
        if (mounted) setState(() => _message = null);
      },
    );
  }

  String _thai(Object e) =>
      e is ApiException ? e.message : 'โหลดข้อมูลสิทธิ์ไม่สำเร็จ';
  bool _visible(int type, String action) =>
      MenuPermissionSelection.isActionVisible(type, action);
  String _systemKey(MenuPermissionRow row) =>
      row.projectId?.toString() ?? '_CORE';

  String _systemLabel(MenuPermissionRow row) {
    final projectName = row.projectName?.trim() ?? '';
    return projectName.isEmpty ? 'ส่วนกลาง' : projectName;
  }

  List<MenuPermissionRow> get _systemLevels =>
      _rows.fold<List<MenuPermissionRow>>(<MenuPermissionRow>[], (levels, row) {
        return levels.any((item) => _systemKey(item) == _systemKey(row))
            ? levels
            : [...levels, row];
      });

  List<MenuPermissionRow> get _systemFilteredRows =>
      _selectedSystemLevel == null
      ? _rows
      : _rows.where((row) => _systemKey(row) == _selectedSystemLevel).toList();

  List<MenuPermissionRow> get _filteredRows => _selectedMenuGroup == null
      ? _systemFilteredRows
      : _systemFilteredRows
            .where((row) => row.groupKey == _selectedMenuGroup)
            .toList();

  List<MenuPermissionRow> get _menuGroups => _systemFilteredRows
      .where((e) => e.menuGroupCode.isNotEmpty)
      .fold<List<MenuPermissionRow>>(
        <MenuPermissionRow>[],
        (all, row) =>
            all.any((e) => e.groupKey == row.groupKey) ? all : [...all, row],
      );
  void _change(MenuPermissionRow row, String action, bool value) {
    if (!_canEdit) return;
    setState(
      () => _rows = _rows
          .map(
            (item) =>
                item.projectId == row.projectId && item.menuCode == row.menuCode
                ? MenuPermissionSelection.applyToRow(item, action, value)
                : item,
          )
          .toList(),
    );
  }

  void _changeGroup(String menuGroupCode, String action, bool value) {
    if (!_canEdit) return;
    setState(
      () => _rows = MenuPermissionSelection.applyToGroup(
        _rows,
        menuGroupCode,
        action,
        value,
      ),
    );
  }

  bool? _groupValue(String menuGroupCode, String action) =>
      MenuPermissionSelection.groupValue(_rows, menuGroupCode, action);

  bool _groupHasAction(String menuGroupCode, String action) =>
      MenuPermissionSelection.hasAction(_rows, menuGroupCode, action);

  bool _isGroupCollapsed(String menuGroupCode) =>
      _collapsedMenuGroups.contains(menuGroupCode);

  void _toggleMenuGroup(String menuGroupCode) {
    setState(() {
      if (!_collapsedMenuGroups.add(menuGroupCode)) {
        _collapsedMenuGroups.remove(menuGroupCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'สิทธิ์เมนู',
    activeMenu: widget.activeMenu,
    menuScope: widget.scope == 'laoo'
        ? WorkspaceMenuScope.support
        : widget.scope == 'partner'
        ? WorkspaceMenuScope.partner
        : WorkspaceMenuScope.company,
    child: ColoredBox(
      color: const Color(0xFFF8F9FB),
      child: ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (context, _, _) => Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WorkspaceActionHeader(
                            title: 'สิทธิ์เมนู',
                            favoriteKey: widget.scope == 'laoo'
                                ? '12004'
                                : widget.scope == 'partner'
                                ? '11004'
                                : '10004',
                            actions: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .10),
                                ),
                                child: IconButton(
                                  tooltip: _card
                                      ? 'แสดงแบบรายการ'
                                      : 'แสดงแบบการ์ด',
                                  color: Theme.of(context).colorScheme.primary,
                                  onPressed: () =>
                                      setState(() => _card = !_card),
                                  icon: Icon(
                                    _card
                                        ? Icons.view_list_outlined
                                        : Icons.grid_view_outlined,
                                  ),
                                ),
                              ),
                              if (_canDelete)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _saving || _selectedGroup == null
                                      ? null
                                      : _clearAll,
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                  ),
                                  label: const Text('ลบสิทธิ์ทั้งหมด'),
                                ),
                              if (_canEdit)
                                FilledButton.icon(
                                  onPressed: _saving || _selectedGroup == null
                                      ? null
                                      : _save,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('บันทึก'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final fieldWidth = constraints.maxWidth < 760
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedGroup,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'กลุ่มสิทธิ์',
                                    labelStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    floatingLabelStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  items: _roleGroups
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g.id,
                                          child: Text(
                                            g.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() => _selectedGroup = v);
                                    _loadRows();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedSystemLevel,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'ระดับระบบ',
                                    labelStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    floatingLabelStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'ทั้งหมด',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    ..._systemLevels.map(
                                      (level) => DropdownMenuItem<String>(
                                        value: _systemKey(level),
                                        child: Text(
                                          _systemLabel(level),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _selectedSystemLevel = value;
                                    _selectedMenuGroup = null;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedMenuGroup,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'กลุ่มเมนู',
                                    labelStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    floatingLabelStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'ทั้งหมด',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    ..._menuGroups.map(
                                      (g) => DropdownMenuItem<String>(
                                        value: g.groupKey,
                                        child: Text(
                                          g.menuGroupName,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _selectedMenuGroup = value,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _table(context),
                  ),
                ],
              ),
            ),
            if (_message != null)
              Positioned(
                top: 12,
                right: 24,
                child: Material(
                  elevation: 8,
                  color:
                      (_error
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _message!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () {
                            _alertTimer?.cancel();
                            setState(() => _message = null);
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _table(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_card || constraints.maxWidth < 900) {
          return _mobileCards(context);
        }
        final columns = _tableColumns(context);
        final headerColor = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .10);
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 12,
                  horizontalMargin: 16,
                  headingRowColor: WidgetStatePropertyAll(headerColor),
                  columns: columns,
                  rows: const [],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 16,
                      headingRowHeight: 0,
                      columns: columns,
                      rows: _tableRows(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DataColumn> _tableColumns(BuildContext context) => [
    DataColumn(label: _menuHeaderCell(context)),
    DataColumn(label: _headerCell(context, 'แสดง')),
    DataColumn(label: _headerCell(context, 'เพิ่ม')),
    DataColumn(label: _headerCell(context, 'แก้ไข')),
    DataColumn(label: _headerCell(context, 'ลบ')),
  ];

  Widget _mobileCards(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final groups = _menuGroups
        .where(
          (group) => _filteredRows.any((row) => row.groupKey == group.groupKey),
        )
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final group = groups[index];
        final collapsed = _isGroupCollapsed(group.groupKey);
        final groupRows = _filteredRows
            .where((row) => row.groupKey == group.groupKey)
            .toList();
        return Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                color: primary.withValues(alpha: .07),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 20,
                          color: primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.groupLabel,
                            style: TextStyle(
                              color: primary,
                              fontSize: LaooTypography.sectionTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${groupRows.length} เมนู',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: LaooTypography.caption,
                          ),
                        ),
                        IconButton(
                          tooltip: collapsed ? 'ขยายกลุ่มเมนู' : 'ยุบกลุ่มเมนู',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _toggleMenuGroup(group.groupKey),
                          icon: Icon(
                            collapsed
                                ? Icons.keyboard_arrow_down_outlined
                                : Icons.keyboard_arrow_up_outlined,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          const [
                            ('แสดง', 'VIEW'),
                            ('เพิ่ม', 'CREATE'),
                            ('แก้ไข', 'EDIT'),
                            ('ลบ', 'DELETE'),
                          ].map((action) {
                            if (!_groupHasAction(group.groupKey, action.$2)) {
                              return const SizedBox.shrink();
                            }
                            return _permissionControl(
                              context,
                              label: action.$1,
                              value: _groupValue(group.groupKey, action.$2),
                              enabled: _canEdit,
                              tristate: true,
                              emphasized: true,
                              onChanged: (value) => _changeGroup(
                                group.groupKey,
                                action.$2,
                                value,
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              if (!collapsed)
                for (var rowIndex = 0; rowIndex < groupRows.length; rowIndex++)
                  _mobilePermissionRow(
                    context,
                    groupRows[rowIndex],
                    showDivider: rowIndex > 0,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobilePermissionRow(
    BuildContext context,
    MenuPermissionRow row, {
    required bool showDivider,
  }) {
    final actions = <(String, String, bool)>[
      ('แสดง', 'VIEW', row.canView),
      ('เพิ่ม', 'CREATE', row.canCreate),
      ('แก้ไข', 'EDIT', row.canEdit),
      ('ลบ', 'DELETE', row.canDelete),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider) const Divider(height: 1, color: LaooColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.menuName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LaooColors.textPrimary,
                  fontSize: LaooTypography.tableBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: actions.map((action) {
                  final visible = _visible(row.screenType, action.$2);
                  if (!visible) return const SizedBox.shrink();
                  final enabled =
                      _canEdit && (action.$2 == 'VIEW' || row.canView);
                  return _permissionControl(
                    context,
                    label: action.$1,
                    value: action.$3,
                    enabled: enabled,
                    onChanged: (value) => _change(row, action.$2, value),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<DataRow> _tableRows(BuildContext tableContext) {
    final result = <DataRow>[];
    String? lastGroup;
    for (final row in _filteredRows) {
      if (row.groupKey != lastGroup) {
        lastGroup = row.groupKey;
        final collapsed = _isGroupCollapsed(row.groupKey);
        result.add(
          DataRow(
            color: WidgetStatePropertyAll(
              Theme.of(tableContext).colorScheme.primary.withValues(alpha: .06),
            ),
            cells: [
              DataCell(
                SizedBox(
                  width: _menuColumnWidth,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: collapsed ? 'ขยายกลุ่มเมนู' : 'ยุบกลุ่มเมนู',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleMenuGroup(row.groupKey),
                        icon: Icon(
                          collapsed
                              ? Icons.keyboard_arrow_right_outlined
                              : Icons.keyboard_arrow_down_outlined,
                          size: 20,
                          color: Theme.of(tableContext).colorScheme.primary,
                        ),
                      ),
                      Icon(
                        Icons.folder_open_outlined,
                        size: 20,
                        color: Theme.of(tableContext).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.groupLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(tableContext).colorScheme.primary,
                            fontSize: LaooTypography.tableHeader,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _groupCell(tableContext, row.groupKey, 'VIEW'),
              _groupCell(tableContext, row.groupKey, 'CREATE'),
              _groupCell(tableContext, row.groupKey, 'EDIT'),
              _groupCell(tableContext, row.groupKey, 'DELETE'),
            ],
          ),
        );
      }
      if (_isGroupCollapsed(row.groupKey)) continue;
      result.add(
        DataRow(
          cells: [
            DataCell(Text(row.menuName)),
            _cell(row, 'VIEW', row.canView),
            _cell(row, 'CREATE', row.canCreate),
            _cell(row, 'EDIT', row.canEdit),
            _cell(row, 'DELETE', row.canDelete),
          ],
        ),
      );
    }
    return result;
  }

  Widget _headerCell(BuildContext context, String text) => SizedBox(
    width: _permissionColumnWidth,
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: LaooTypography.tableHeader,
        ),
      ),
    ),
  );
  Widget _menuHeaderCell(BuildContext context) => SizedBox(
    width: _menuColumnWidth,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'เมนู',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: LaooTypography.tableHeader,
        ),
      ),
    ),
  );
  DataCell _cell(MenuPermissionRow row, String action, bool value) => DataCell(
    SizedBox(
      width: _permissionColumnWidth,
      child: Center(
        child:
            _visible(row.screenType, action) &&
                (action == 'VIEW' || row.canView)
            ? _permissionCheckbox(
                value: value,
                enabled: _canEdit,
                semanticLabel: '$action ${row.menuName}',
                onChanged: (selected) => _change(row, action, selected),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );

  DataCell _groupCell(
    BuildContext context,
    String menuGroupCode,
    String action,
  ) => DataCell(
    SizedBox(
      width: _permissionColumnWidth,
      child: Center(
        child: _groupHasAction(menuGroupCode, action)
            ? _permissionCheckbox(
                value: _groupValue(menuGroupCode, action),
                enabled: _canEdit,
                tristate: true,
                semanticLabel: '$action ทั้งกลุ่ม',
                onChanged: (selected) =>
                    _changeGroup(menuGroupCode, action, selected),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );

  Widget _permissionControl(
    BuildContext context, {
    required String label,
    required bool? value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    bool tristate = false,
    bool emphasized = false,
  }) => Container(
    padding: const EdgeInsets.only(right: 6),
    decoration: emphasized
        ? BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          )
        : null,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _permissionCheckbox(
          value: value,
          enabled: enabled,
          tristate: tristate,
          semanticLabel: label,
          onChanged: onChanged,
        ),
        Text(
          label,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).disabledColor,
            fontSize: LaooTypography.tableBody,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );

  Widget _permissionCheckbox({
    required bool? value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required String semanticLabel,
    bool tristate = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Checkbox(
      value: value,
      tristate: tristate,
      semanticLabel: semanticLabel,
      onChanged: enabled ? (_) => onChanged(value != true) : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      side: BorderSide(
        color: enabled ? primary.withValues(alpha: .72) : LaooColors.border,
        width: 1.4,
      ),
      checkColor: Colors.white,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) return Colors.transparent;
        return enabled ? primary : LaooColors.textSecondary;
      }),
      overlayColor: WidgetStatePropertyAll(
        primary.withValues(alpha: enabled ? .10 : 0),
      ),
    );
  }
}
