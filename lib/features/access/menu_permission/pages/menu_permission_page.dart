import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../role_group/data/role_group_repository.dart';
import '../../role_group/models/role_group.dart';
import '../data/menu_permission_repository.dart';
import '../models/menu_permission_row.dart';
import '../models/menu_permission_selection.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../company/ocr/business_card_ocr_ui.dart';

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
  List<MenuPermissionRow> _savedRows = const [];
  int? _selectedGroup;
  String? _selectedSystemLevel;
  String? _selectedMenuGroup;
  bool _loading = true, _saving = false;
  bool _canEdit = false, _canDelete = false;
  String? _message;
  bool _error = false;
  int _alertSerial = 0;
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
      setState(() {
        _rows = const [];
        _savedRows = const [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await _permissions.list(widget.scope, id);
      if (mounted) {
        setState(() {
          _rows = rows;
          _savedRows = List.of(rows);
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
    final submitted = List<MenuPermissionRow>.of(_rows);
    setState(() => _saving = true);
    try {
      await _permissions.save(widget.scope, id, submitted);
      if (mounted && _selectedGroup == id) {
        setState(() => _savedRows = submitted);
      }
      _show('บันทึกสิทธิ์เมนูสำเร็จ');
    } catch (e) {
      _showError(_thai(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _grantAll() async {
    final id = _selectedGroup;
    if (widget.scope != 'customer' ||
        !_canEdit ||
        id == null ||
        _saving ||
        _loading) {
      return;
    }
    if (!MenuPermissionSelection.samePermissions(_rows, _savedRows)) {
      _showError(
        'มีการแก้ไขสิทธิ์ที่ยังไม่บันทึก กรุณาบันทึกหรือโหลดรายการใหม่ก่อน',
      );
      return;
    }
    if (_rows.isEmpty) {
      _showError('ไม่พบเมนูที่บริษัทเปิดใช้งาน');
      return;
    }
    final group = _roleGroups.where((item) => item.id == id).firstOrNull;
    final count = _rows.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: workspaceThemeController.value.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ยืนยันให้สิทธิ์ทุกเมนู',
                    style: LaooTypography.popupTitleStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: .6,
              thickness: .6,
              color: workspaceThemeController.value.border,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('กลุ่มสิทธิ์: ${group?.name ?? '-'}\nจำนวน $count เมนู'),
            const SizedBox(height: 12),
            Divider(
              height: .6,
              thickness: .6,
              color: workspaceThemeController.value.border,
            ),
            const SizedBox(height: 12),
            const Text(
              'กำหนดสิทธิ์ทุกระบบที่บริษัทเปิดใช้งาน รวมเมนูที่ถูกกรองอยู่ โดยสิทธิ์ระดับย่อยยังคงเดิม',
            ),
          ],
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(
                height: .6,
                thickness: .6,
                color: workspaceThemeController.value.border,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('ยืนยัน'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _selectedGroup != id) return;
    setState(() => _saving = true);
    try {
      final latest = await _permissions.list(widget.scope, id);
      if (!mounted || _selectedGroup != id) return;
      if (!MenuPermissionSelection.samePermissions(_rows, _savedRows) ||
          !MenuPermissionSelection.samePermissions(latest, _savedRows)) {
        _showError('ข้อมูลสิทธิ์เปลี่ยนแปลง กรุณาโหลดรายการใหม่ก่อนดำเนินการ');
        return;
      }
      final granted = MenuPermissionSelection.grantAll(latest);
      await _permissions.save(widget.scope, id, granted);
      if (!mounted || _selectedGroup != id) return;
      setState(() {
        _rows = granted;
        _savedRows = List.of(granted);
      });
      _show('ให้สิทธิ์ทุกเมนูเรียบร้อยแล้ว');
    } catch (e) {
      if (mounted) _showError(_thai(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        _savedRows = List.of(_rows);
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
    if (!mounted) return;
    setState(() {
      _message = text;
      _error = error;
      _alertSerial++;
    });
  }

  String _thai(Object e) =>
      e is ApiException ? e.message : 'โหลดข้อมูลสิทธิ์ไม่สำเร็จ';
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
    if (!_canEdit || _saving) return;
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
    if (!_canEdit || _saving) return;
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

  Future<void> _bulkMenu(
    MenuPermissionRow row, {
    required bool group,
    required bool grant,
  }) async {
    final roleId = _selectedGroup;
    if (widget.scope != 'customer' ||
        !_canEdit ||
        _saving ||
        roleId == null ||
        row.projectId == null) {
      return;
    }
    if (!MenuPermissionSelection.samePermissions(_rows, _savedRows)) {
      _showError(
        'มีการแก้ไขสิทธิ์ที่ยังไม่บันทึก กรุณาบันทึกหรือโหลดรายการใหม่ก่อน',
      );
      return;
    }
    final label = group ? row.groupLabel : row.menuName;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: workspaceThemeController.value.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    grant
                        ? 'ยืนยันให้สิทธิ์ทุกกลุ่ม'
                        : 'ยืนยันยกเลิกสิทธิ์ทุกกลุ่ม',
                    style: LaooTypography.popupTitleStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: .6,
              thickness: .6,
              color: workspaceThemeController.value.border,
            ),
          ],
        ),
        content: Text(
          '${grant ? 'ให้สิทธิ์ทุก Action ที่หน้าจอรองรับ' : 'ยกเลิกสิทธิ์ทุก Action'} สำหรับ $label กับกลุ่มสิทธิ์ที่ใช้งานอยู่ทุกกลุ่มในบริษัท\n\nสิทธิ์ระดับย่อยและสถานะ Company Admin ไม่เปลี่ยนแปลง',
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(
                height: .6,
                thickness: .6,
                color: workspaceThemeController.value.border,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('ยืนยัน'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    if (!MenuPermissionSelection.samePermissions(_rows, _savedRows) ||
        _selectedGroup != roleId) {
      _showError('ข้อมูลสิทธิ์เปลี่ยนระหว่างยืนยัน กรุณาตรวจสอบแล้วลองใหม่');
      return;
    }
    setState(() => _saving = true);
    try {
      await _permissions.bulkMenu(
        roleGroupId: roleId,
        projectId: row.projectId!,
        menuGroupCode: row.menuGroupCode,
        menuCode: group ? null : row.menuCode,
        grant: grant,
      );
      await _loadRows();
      if (mounted) {
        _show(
          grant
              ? 'ให้สิทธิ์ทุกกลุ่มเรียบร้อยแล้ว'
              : 'ยกเลิกสิทธิ์ทุกกลุ่มเรียบร้อยแล้ว',
        );
      }
    } catch (e) {
      if (mounted) _showError(_thai(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _bulkMenuButtons(MenuPermissionRow row, {required bool group}) {
    if (widget.scope != 'customer' || !_canEdit || row.projectId == null) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<bool>(
      enabled: !_saving && !_loading,
      tooltip: 'กำหนดสิทธิ์ทุกกลุ่ม',
      icon: const Icon(Icons.more_vert),
      onSelected: (grant) => _bulkMenu(row, group: group, grant: grant),
      itemBuilder: (_) => const [
        PopupMenuItem(value: true, child: Text('ไม่จำกัดสิทธิ์ทุกกลุ่ม')),
        PopupMenuItem(value: false, child: Text('ยกเลิกสิทธิ์ทุกกลุ่ม')),
      ],
    );
  }

  bool _isGroupCollapsed(String menuGroupCode) =>
      _collapsedMenuGroups.contains(menuGroupCode);

  void _toggleMenuGroup(String menuGroupCode) {
    setState(() {
      if (!_collapsedMenuGroups.add(menuGroupCode)) {
        _collapsedMenuGroups.remove(menuGroupCode);
      }
    });
  }

  Future<void> _chooseRoleGroup() async {
    if (_saving || _loading) return;
    var query = '';
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final primary = Theme.of(context).colorScheme.primary;
          final matches = _roleGroups
              .where(
                (group) =>
                    group.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.search, color: primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('ค้นหากลุ่มสิทธิ์')),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: MediaQuery.sizeOf(context).height * .5,
              child: Column(
                children: [
                  const Divider(thickness: .6),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: businessCardOcrUi(context).inputStyle,
                    decoration: ocrInput(
                      context,
                      'ค้นหากลุ่มสิทธิ์',
                      icon: Icons.search,
                    ),
                    onChanged: (value) => update(() => query = value.trim()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('ไม่พบกลุ่มสิทธิ์'))
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, thickness: .6),
                            itemBuilder: (context, index) => ListTile(
                              title: Text(matches[index].name),
                              onTap: () => Navigator.pop(
                                dialogContext,
                                matches[index].id,
                              ),
                            ),
                          ),
                  ),
                  const Divider(thickness: .6),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || selected == null || selected == _selectedGroup) return;
    if (!MenuPermissionSelection.samePermissions(_rows, _savedRows)) {
      _showError(
        'มีการแก้ไขสิทธิ์ที่ยังไม่บันทึก กรุณาบันทึกก่อนเปลี่ยนกลุ่มสิทธิ์',
      );
      return;
    }
    setState(() => _selectedGroup = selected);
    await _loadRows();
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
                              if (MediaQuery.sizeOf(context).width > 600)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: .10),
                                  ),
                                  child: SizedBox.square(
                                    dimension: LaooTypography.buttonHeight,
                                    child: IconButton(
                                      tooltip: _card
                                          ? 'แสดงแบบรายการ'
                                          : 'แสดงแบบการ์ด',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      onPressed: () =>
                                          setState(() => _card = !_card),
                                      icon: Icon(
                                        _card
                                            ? Icons.view_list_outlined
                                            : Icons.grid_view_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                              if (widget.scope == 'customer' && _canEdit)
                                FilledButton.icon(
                                  onPressed:
                                      _saving ||
                                          _loading ||
                                          _selectedGroup == null
                                      ? null
                                      : _grantAll,
                                  icon: const Icon(Icons.done_all),
                                  label: const Text('ให้สิทธิ์ทุกเมนู'),
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
                                child: TextFormField(
                                  key: ValueKey('role-group-$_selectedGroup'),
                                  initialValue:
                                      _roleGroups
                                          .where((g) => g.id == _selectedGroup)
                                          .map((g) => g.name)
                                          .firstOrNull ??
                                      '',
                                  readOnly: true,
                                  enabled: !_saving && !_loading,
                                  style: TextStyle(
                                    fontSize: LaooTypography.comboBox,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: ocrInput(context, 'กลุ่มสิทธิ์')
                                      .copyWith(
                                        suffixIcon: Icon(
                                          Icons.search,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                  onTap: _chooseRoleGroup,
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedSystemLevel,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: LaooTypography.comboBox,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'ระดับระบบ',
                                    labelStyle: TextStyle(
                                      fontSize: LaooTypography
                                          .materialFloatingLabelSource,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    floatingLabelStyle: TextStyle(
                                      fontSize: LaooTypography
                                          .materialFloatingLabelSource,
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
                                    final groups = _menuGroups;
                                    _selectedMenuGroup =
                                        value != null &&
                                            groups.length == 1 &&
                                            groups
                                                    .first
                                                    .configuredMenuGroupCount ==
                                                1
                                        ? groups.first.groupKey
                                        : null;
                                    if (_selectedMenuGroup != null) {
                                      _collapsedMenuGroups.remove(
                                        _selectedMenuGroup,
                                      );
                                    }
                                  }),
                                ),
                              ),
                              if (!(_selectedSystemLevel != null &&
                                  _menuGroups.length == 1 &&
                                  _menuGroups.first.configuredMenuGroupCount ==
                                      1))
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedMenuGroup,
                                    isExpanded: true,
                                    style: TextStyle(
                                      fontSize: LaooTypography.comboBox,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'กลุ่มเมนู',
                                      labelStyle: TextStyle(
                                        fontSize: LaooTypography
                                            .materialFloatingLabelSource,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      floatingLabelStyle: TextStyle(
                                        fontSize: LaooTypography
                                            .materialFloatingLabelSource,
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
                                            style: const TextStyle(
                                              fontSize: LaooTypography.comboBox,
                                            ),
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
                left: 24,
                child: AutoDismissMessage(
                  key: ValueKey(_alertSerial),
                  message: _message!,
                  error: _error,
                  onClose: () {
                    if (mounted) setState(() => _message = null);
                  },
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
        if (_card || MediaQuery.sizeOf(context).width <= 600) {
          return _mobileCards(context);
        }
        final columns = _tableColumns(context);
        final headerColor = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .10);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (constraints.maxWidth - 2 * LaooLayout.cardPadding).clamp(
                966.0,
                double.infinity,
              ),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth:
                          (constraints.maxWidth - 2 * LaooLayout.cardPadding)
                              .clamp(0.0, double.infinity),
                    ),
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
                        constraints: BoxConstraints(
                          minWidth:
                              (constraints.maxWidth -
                                      2 * LaooLayout.cardPadding)
                                  .clamp(0.0, double.infinity),
                        ),
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
            ),
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
    DataColumn(label: _headerCell(context, 'พิมพ์')),
    DataColumn(label: _headerCell(context, 'ส่งออก')),
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
                color: Colors.white,
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
                        _bulkMenuButtons(group, group: true),
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
                            ('พิมพ์', 'PRINT'),
                            ('ส่งออก', 'EXPORT'),
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
      ('พิมพ์', 'PRINT', row.canPrint),
      ('ส่งออก', 'EXPORT', row.canExport),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.menuName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LaooColors.textPrimary,
                        fontSize: LaooTypography.tableBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _bulkMenuButtons(row, group: false),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: actions.map((action) {
                  final visible = MenuPermissionSelection.supports(
                    row,
                    action.$2,
                  );
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
            color: const WidgetStatePropertyAll(Colors.white),
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
                      _bulkMenuButtons(row, group: true),
                    ],
                  ),
                ),
              ),
              _groupCell(tableContext, row.groupKey, 'VIEW'),
              _groupCell(tableContext, row.groupKey, 'CREATE'),
              _groupCell(tableContext, row.groupKey, 'EDIT'),
              _groupCell(tableContext, row.groupKey, 'DELETE'),
              _groupCell(tableContext, row.groupKey, 'PRINT'),
              _groupCell(tableContext, row.groupKey, 'EXPORT'),
            ],
          ),
        );
      }
      if (_isGroupCollapsed(row.groupKey)) continue;
      result.add(
        DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: _menuColumnWidth,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.menuName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _bulkMenuButtons(row, group: false),
                  ],
                ),
              ),
            ),
            _cell(row, 'VIEW', row.canView),
            _cell(row, 'CREATE', row.canCreate),
            _cell(row, 'EDIT', row.canEdit),
            _cell(row, 'DELETE', row.canDelete),
            _cell(row, 'PRINT', row.canPrint),
            _cell(row, 'EXPORT', row.canExport),
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
            MenuPermissionSelection.supports(row, action) &&
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
    final primary = workspaceThemeController.value.primary;
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
