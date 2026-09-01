import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../role_group/data/role_group_repository.dart';
import '../../role_group/models/role_group.dart';
import '../data/menu_permission_repository.dart';
import '../models/menu_permission_row.dart';
import '../../../profile/pages/user_profile_dialog.dart';

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
  List<RoleGroup> _roleGroups = const [];
  List<MenuPermissionRow> _rows = const [];
  int? _selectedGroup;
  String? _selectedMenuGroup;
  bool _loading = true, _saving = false;
  bool _canEdit = false, _canDelete = false;
  bool _showCards = false;
  String? _message;
  bool _error = false;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _showCards = userDefaultViewModeNotifier.value == 'CARD';
    userDefaultViewModeNotifier.addListener(_syncDefaultViewMode);
    _loadActions();
    _loadGroups();
  }

  @override
  void dispose() {
    userDefaultViewModeNotifier.removeListener(_syncDefaultViewMode);
    _alertTimer?.cancel();
    super.dispose();
  }

  void _syncDefaultViewMode() {
    if (mounted)
      setState(() => _showCards = userDefaultViewModeNotifier.value == 'CARD');
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
            insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
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
                        style: LaooTypography.popupTitleStyle,
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
    child: ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, _, _) => Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: WorkspaceActionHeader(
                    title: 'สิทธิ์เมนู',
                    favoriteKey: widget.scope == 'laoo'
                        ? '12004'
                        : widget.scope == 'partner'
                        ? '11004'
                        : '10004',
                    actions: [
                      if (MediaQuery.sizeOf(context).width >= 900)
                        IconButton(
                          tooltip: _showCards ? 'แสดง List' : 'แสดง Card',
                          style: IconButton.styleFrom(
                            foregroundColor:
                                workspaceThemeController.value.primary,
                            side: BorderSide(
                              color: workspaceThemeController.value.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _showCards = !_showCards),
                          icon: Icon(
                            _showCards
                                ? Icons.table_rows_outlined
                                : Icons.grid_view_outlined,
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
                          icon: const Icon(Icons.delete_forever_outlined),
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
                ),
                const SizedBox(height: 8),
                WorkspaceSectionCard(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = <Widget>[
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _selectedGroup,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: 'กลุ่มสิทธิ์',
                              constraints: const BoxConstraints(minHeight: 48),
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
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedMenuGroup,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: 'กลุ่มเมนู',
                              constraints: const BoxConstraints(minHeight: 48),
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
                        ];
                        if (constraints.maxWidth < 700) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              fields.first,
                              const SizedBox(height: 12),
                              fields.last,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: fields.first),
                            const SizedBox(width: 12),
                            Expanded(child: fields.last),
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
            if (_message != null)
              Positioned(
                top: 12,
                right: 24,
                child: AutoDismissMessage(
                  message: _message!,
                  error: _error,
                  onClose: () {
                    _alertTimer?.cancel();
                    setState(() => _message = null);
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _table(BuildContext context) {
    final preset = workspaceThemeController.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_showCards || constraints.maxWidth < 900) {
          return _mobileCards(context);
        }
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: LaooColors.white,
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: DataTable(
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: LaooColors.border.withValues(alpha: .45),
                  width: .25,
                ),
              ),
              headingRowColor: WidgetStatePropertyAll(
                preset.primary.withValues(alpha: .10),
              ),
              columns: [
                DataColumn(label: _menuHeaderCell(context)),
                DataColumn(label: _headerCell(context, 'แสดง')),
                DataColumn(label: _headerCell(context, 'เพิ่ม')),
                DataColumn(label: _headerCell(context, 'แก้ไข')),
                DataColumn(label: _headerCell(context, 'ลบ')),
              ],
              rows: _tableRows(),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileCards(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView.separated(
      padding: EdgeInsets.zero,
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
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
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
                      fontSize: LaooTypography.tableBody,
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
                        Checkbox(
                          value: action.$3,
                          onChanged: enabled
                              ? (value) =>
                                    _change(row, action.$2, value ?? false)
                              : null,
                          activeColor: primary,
                          visualDensity: VisualDensity.compact,
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

  List<DataRow> _tableRows() {
    final result = <DataRow>[];
    String? lastGroup;
    for (final row in _filteredRows) {
      if (row.menuGroupCode != lastGroup) {
        lastGroup = row.menuGroupCode;
        result.add(
          DataRow(
            color: WidgetStatePropertyAll(LaooColors.white),
            cells: [
              DataCell(
                Text(
                  row.menuGroupName,
                  style: TextStyle(
                    color: workspaceThemeController.value.primary,
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

  Widget _headerCell(BuildContext context, String text) => SizedBox(
    width: 100,
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: workspaceThemeController.value.primary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
  );
  Widget _menuHeaderCell(BuildContext context) => SizedBox(
    width: 100,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'เมนู',
        style: TextStyle(
          color: workspaceThemeController.value.primary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
  );
  DataCell _cell(MenuPermissionRow row, String action, bool value) => DataCell(
    SizedBox(
      width: 100,
      child: Center(
        child:
            _visible(row.screenType, action) &&
                (action == 'VIEW' || row.canView)
            ? Checkbox(
                value: value,
                onChanged: (v) => _change(row, action, v ?? false),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );
}
