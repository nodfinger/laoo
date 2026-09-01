import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../role_group/data/role_group_repository.dart';
import '../../role_group/models/role_group.dart';
import '../data/menu_permission_repository.dart';
import '../models/menu_permission_row.dart';
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
  final _groups = RoleGroupRepository();
  final _permissions = MenuPermissionRepository();
  final _profile = UserProfileRepository();
  List<RoleGroup> _roleGroups = const [];
  List<MenuPermissionRow> _rows = const [];
  int? _selectedGroup;
  String? _selectedMenuGroup;
  bool _loading = true, _saving = false;
  bool _canEdit = false, _canDelete = false;
  String? _message;
  bool _error = false;
  Timer? _alertTimer;
  bool _card = false;

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
          _selectedMenuGroup = null;
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
                        style: LaooTypography.screenCaptionStyle,
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
      action == 'VIEW' ||
      (type == 1 && {'CREATE', 'EDIT', 'DELETE'}.contains(action)) ||
      (type == 2 && action == 'EDIT');
  List<MenuPermissionRow> get _filteredRows => _selectedMenuGroup == null
      ? _rows
      : _rows.where((e) => e.menuGroupCode == _selectedMenuGroup).toList();
  List<MenuPermissionRow> get _menuGroups => _rows
      .where((e) => e.menuGroupCode.isNotEmpty)
      .fold<List<MenuPermissionRow>>(
        <MenuPermissionRow>[],
        (all, row) => all.any((e) => e.menuGroupCode == row.menuGroupCode)
            ? all
            : [...all, row],
      );
  void _change(MenuPermissionRow row, String action, bool value) => setState(
    () => _rows = _rows.map((e) {
      if (e.menuCode != row.menuCode) return e;
      if (action == 'VIEW' && !value) {
        return e.copy(view: false, create: false, edit: false, delete: false);
      }
      return e.copy(
        view: action == 'VIEW' ? value : null,
        create: action == 'CREATE' ? value : null,
        edit: action == 'EDIT' ? value : null,
        delete: action == 'DELETE' ? value : null,
      );
    }).toList(),
  );

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
              padding: const EdgeInsets.all(24),
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
                          Row(
                            children: [
                              WorkspacePageTitle(
                                title: 'สิทธิ์เมนู',
                                favoriteKey: widget.scope == 'laoo'
                                    ? '12004'
                                    : widget.scope == 'partner'
                                    ? '11004'
                                    : '10004',
                                titleColor: Colors.black,
                              ),
                              const Spacer(),
                              const SizedBox(width: 8),
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
                              if (_canDelete) const SizedBox(width: 8),
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
                              if (_canDelete && _canEdit)
                                const SizedBox(width: 8),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedGroup,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'กลุ่มสิทธิ์',
                                labelStyle: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                floatingLabelStyle: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              items: _roleGroups
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g.id,
                                      child: Text(
                                        g.name,
                                        style: const TextStyle(fontSize: 14),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedMenuGroup,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'กลุ่มเมนู',
                                labelStyle: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                floatingLabelStyle: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
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
                                    value: g.menuGroupCode,
                                    child: Text(
                                      g.menuGroupName,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedMenuGroup = value),
                            ),
                          ),
                        ],
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
        if (_card || constraints.maxWidth < 600) {
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
                  headingRowColor: WidgetStatePropertyAll(headerColor),
                  horizontalMargin: 24,
                  columnSpacing: 0,
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
                      headingRowHeight: 0,
                      horizontalMargin: 24,
                      columnSpacing: 0,
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
    DataColumn(
      columnWidth: const FlexColumnWidth(2.4),
      label: _menuHeaderCell(context),
    ),
    DataColumn(
      columnWidth: const FlexColumnWidth(),
      headingRowAlignment: MainAxisAlignment.center,
      label: _headerCell(context, 'แสดง'),
    ),
    DataColumn(
      columnWidth: const FlexColumnWidth(),
      headingRowAlignment: MainAxisAlignment.center,
      label: _headerCell(context, 'เพิ่ม'),
    ),
    DataColumn(
      columnWidth: const FlexColumnWidth(),
      headingRowAlignment: MainAxisAlignment.center,
      label: _headerCell(context, 'แก้ไข'),
    ),
    DataColumn(
      columnWidth: const FlexColumnWidth(),
      headingRowAlignment: MainAxisAlignment.center,
      label: _headerCell(context, 'ลบ'),
    ),
  ];

  Widget _mobileCards(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _filteredRows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = _filteredRows[index];
        final actions = <(String, String, bool)>[
          ('ดู', 'VIEW', row.canView),
          ('เพิ่ม', 'CREATE', row.canCreate),
          ('แก้ไข', 'EDIT', row.canEdit),
          ('ลบ', 'DELETE', row.canDelete),
        ];
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  row.menuName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                ),
                if (row.menuGroupName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.menuGroupName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: actions.map((action) {
                    final enabled = _visible(row.screenType, action.$2);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _permissionCheckbox(
                          value: action.$3,
                          onChanged: enabled
                              ? (value) =>
                                    _change(row, action.$2, value ?? false)
                              : null,
                        ),
                        Text(action.$1),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DataRow> _tableRows(BuildContext tableContext) {
    final result = <DataRow>[];
    String? lastGroup;
    for (final row in _filteredRows) {
      if (row.menuGroupCode != lastGroup) {
        lastGroup = row.menuGroupCode;
        result.add(
          DataRow(
            cells: [
              DataCell(
                Text(
                  row.menuGroupName,
                  style: TextStyle(
                    color: Theme.of(tableContext).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const DataCell(SizedBox.shrink()),
              const DataCell(SizedBox.shrink()),
              const DataCell(SizedBox.shrink()),
              const DataCell(SizedBox.shrink()),
            ],
          ),
        );
      }
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

  Widget _headerCell(BuildContext context, String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );
  Widget _menuHeaderCell(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'เมนู',
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );
  DataCell _cell(MenuPermissionRow row, String action, bool value) => DataCell(
    Center(
      child:
          _visible(row.screenType, action) && (action == 'VIEW' || row.canView)
          ? _permissionCheckbox(
              value: value,
              onChanged: (v) => _change(row, action, v ?? false),
            )
          : const SizedBox.shrink(),
    ),
  );

  Widget _permissionCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        checkColor: Colors.white,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return theme.colorScheme.surfaceContainerHighest;
          }
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.white;
        }),
        overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: .12)),
        side: BorderSide(
          color: enabled
              ? primary.withValues(alpha: .72)
              : theme.colorScheme.outlineVariant,
          width: 1.6,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
