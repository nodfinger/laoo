import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/role_group_repository.dart';
import '../models/role_group.dart';
import '../../../profile/pages/user_profile_dialog.dart';

class RoleGroupPage extends StatefulWidget {
  const RoleGroupPage({
    super.key,
    required this.scope,
    required this.activeMenu,
  });
  final String scope;
  final String activeMenu;
  @override
  State<RoleGroupPage> createState() => _RoleGroupPageState();
}

class _RoleGroupPageState extends State<RoleGroupPage> {
  final _repo = RoleGroupRepository();
  final _search = TextEditingController();
  final _formKey = GlobalKey<_FormState>();
  late Future<List<RoleGroup>> _future;
  RoleGroup? _editing;
  Timer? _alertTimer;
  String? _alert;
  bool _alertError = false;
  bool _form = false;
  bool _loading = false;
  bool _canCreate = false, _canEdit = false, _canDelete = false;
  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _load();
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    final future = _repo.list(widget.scope, search: _search.text);
    setState(() {
      _future = future;
    });
  }

  Future<void> _loadPermissions() async {
    try {
      final p = await _repo.actions(widget.scope);
      if (mounted) {
        setState(() {
          _canCreate = p['create'] == true;
          _canEdit = p['edit'] == true;
          _canDelete = p['delete'] == true;
        });
      }
    } catch (_) {}
  }

  void _notice(String message, {bool error = false}) {
    _alertTimer?.cancel();
    setState(() {
      _alert = message;
      _alertError = error;
    });
    _alertTimer = Timer(
      Duration(seconds: companySetupController.current?.timeAlert ?? 30),
      () {
        if (mounted) setState(() => _alert = null);
      },
    );
  }

  String _thaiError(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('403')) return 'ไม่มีสิทธิ์ดำเนินการรายการนี้';
    if (text.contains('401')) return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
    if (text.contains('404')) return 'ไม่พบข้อมูลที่ต้องการ';
    if (text.contains('409') || text.contains('ซ้ำ')) {
      return 'ข้อมูลนี้มีอยู่แล้ว';
    }
    if (text.contains('SocketException') || text.contains('Timeout')) {
      return 'ไม่สามารถเชื่อมต่อระบบได้';
    }
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }

  Future<void> _save(String code, String name, String desc, bool active) async {
    if (code.trim().isEmpty || name.trim().isEmpty) {
      _notice('กรุณาระบุรหัสและชื่อกลุ่มสิทธิ์', error: true);
      return;
    }
    final editing = _editing != null;
    setState(() => _loading = true);
    try {
      final item = RoleGroup(
        id: _editing?.id ?? 0,
        scope: widget.scope,
        code: code.trim(),
        name: name.trim(),
        description: desc.trim().isEmpty ? null : desc.trim(),
        isActive: active,
      );
      if (editing) {
        await _repo.update(widget.scope, item);
        setState(() {
          _form = false;
          _editing = null;
        });
        _notice('แก้ไขข้อมูลกลุ่มสิทธิ์สำเร็จ');
      } else {
        await _repo.create(widget.scope, item);
        _formKey.currentState?.clearFields();
        _notice('เพิ่มข้อมูลใหม่สำเร็จ');
      }
      _load();
    } catch (e) {
      _notice(_thaiError(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(RoleGroup item) async {
    final preset = workspaceThemeController.value;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => Dialog(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: preset.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.delete_forever_outlined,
                      color: preset.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ยืนยันการลบข้อมูล',
                      style: LaooTypography.popupTitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: preset.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'ต้องการลบ ${item.code} - ${item.name} หรือไม่?',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: Theme.of(c).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(c, true),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (yes != true) return;
    try {
      await _repo.delete(widget.scope, item.id);
      _notice('ลบกลุ่มสิทธิ์สำเร็จ');
      _load();
    } catch (e) {
      _notice(_thaiError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'กลุ่มสิทธิ์',
    activeMenu: widget.activeMenu,
    menuScope: widget.scope == 'partner'
        ? WorkspaceMenuScope.partner
        : widget.scope == 'laoo'
        ? WorkspaceMenuScope.support
        : WorkspaceMenuScope.company,
    child: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _form
                  ? _Form(
                      key: _formKey,
                      onCancel: () => setState(() {
                        _form = false;
                        _editing = null;
                      }),
                      onSave: _save,
                      editing: _editing,
                      loading: _loading,
                      favoriteKey: widget.scope == 'partner'
                          ? '11003'
                          : widget.scope == 'laoo'
                          ? '12003'
                          : '10003',
                    )
                  : _List(
                      future: _future,
                      search: _search,
                      onSearch: _load,
                      canCreate: _canCreate,
                      canEdit: _canEdit,
                      canDelete: _canDelete,
                      favoriteKey: widget.scope == 'partner'
                          ? '11003'
                          : widget.scope == 'laoo'
                          ? '12003'
                          : '10003',
                      onAdd: () => setState(() {
                        _form = true;
                        _editing = null;
                      }),
                      onEdit: (x) => setState(() {
                        _form = true;
                        _editing = x;
                      }),
                      onDelete: _delete,
                    ),
            ),
          ],
        ),
        if (_alert != null)
          Positioned(
            top: 16,
            right: 24,
            child: _AlertBanner(
              message: _alert!,
              error: _alertError,
              onClose: () => setState(() => _alert = null),
            ),
          ),
      ],
    ),
  );
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.message,
    required this.error,
    required this.onClose,
  });
  final String message;
  final bool error;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) {
        final color = error ? Colors.red : preset.primary;
        final foreground = error
            ? Theme.of(context).colorScheme.onError
            : Theme.of(context).colorScheme.onPrimary;
        return Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .50),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error ? Icons.error_outline : Icons.check_circle_outline,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  color: foreground,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCards(
    BuildContext context,
    List<RoleGroup> rows,
    int start,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.code,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            (item.isActive ? primary : theme.colorScheme.error)
                                .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          item.isActive ? 'เปิด' : 'ปิด',
                          style: TextStyle(
                            color: item.isActive
                                ? primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (false)
                      IconButton(
                        tooltip: 'แก้ไข',
                        onPressed: () {},
                        icon: Icon(Icons.edit_outlined, color: primary),
                      ),
                    if (false)
                      IconButton(
                        tooltip: 'ลบ',
                        onPressed: () {},
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
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

class _List extends StatefulWidget {
  const _List({
    required this.future,
    required this.search,
    required this.onSearch,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.favoriteKey,
  });
  final Future<List<RoleGroup>> future;
  final TextEditingController search;
  final VoidCallback onSearch, onAdd;
  final void Function(RoleGroup) onEdit, onDelete;
  final bool canCreate, canEdit, canDelete;
  final String favoriteKey;
  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  int page = 1;
  bool _showCards = false;
  static const pageSize = 10;
  String statusFilter = 'all';
  int? sortColumn;
  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    _showCards = userDefaultViewModeNotifier.value == 'CARD';
    userDefaultViewModeNotifier.addListener(_syncDefaultViewMode);
  }

  @override
  void dispose() {
    userDefaultViewModeNotifier.removeListener(_syncDefaultViewMode);
    super.dispose();
  }

  void _syncDefaultViewMode() {
    if (mounted)
      setState(() => _showCards = userDefaultViewModeNotifier.value == 'CARD');
  }

  void _sort(int column, bool ascending) => setState(() {
    sortColumn = column;
    sortAscending = ascending;
  });

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: Row(
              children: [
                Expanded(
                  child: WorkspacePageTitle(
                    title: 'กลุ่มสิทธิ์',
                    favoriteKey: widget.favoriteKey,
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 900)
                  IconButton(
                    tooltip: _showCards ? 'แสดง List' : 'แสดง Card',
                    style: IconButton.styleFrom(
                      foregroundColor: preset.primary,
                      side: BorderSide(color: preset.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    onPressed: () => setState(() => _showCards = !_showCards),
                    icon: Icon(
                      _showCards
                          ? Icons.table_rows_outlined
                          : Icons.grid_view_outlined,
                    ),
                  ),
                if (MediaQuery.sizeOf(context).width >= 900)
                  const SizedBox(width: 8),
                if (widget.canCreate)
                  FilledButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          WorkspaceSectionCard(
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 600
                        ? constraints.maxWidth
                        : 260,
                    child: TextField(
                      controller: widget.search,
                      onSubmitted: (_) {
                        page = 1;
                        widget.onSearch();
                      },
                      decoration: InputDecoration(
                        labelText: 'ค้นหา',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: widget.onSearch,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: preset.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    onPressed: () {
                      page = 1;
                      widget.onSearch();
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: preset.primary,
                      side: BorderSide(color: preset.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    onPressed: () {
                      widget.search.clear();
                      setState(() {
                        statusFilter = 'all';
                        page = 1;
                      });
                      widget.onSearch();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('ล้าง Filter'),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 600
                        ? constraints.maxWidth
                        : 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: statusFilter,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        labelText: 'สถานะ',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        floatingLabelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(value: 'active', child: Text('เปิด')),
                        DropdownMenuItem(value: 'inactive', child: Text('ปิด')),
                      ],
                      onChanged: (value) => setState(() {
                        statusFilter = value ?? 'all';
                        page = 1;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<RoleGroup>>(
              future: widget.future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 36,
                        ),
                        const Text('โหลดข้อมูลกลุ่มสิทธิ์ไม่สำเร็จ'),
                        const Text('กรุณาลองใหม่อีกครั้ง'),
                        OutlinedButton(
                          onPressed: widget.onSearch,
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final source = snapshot.data!;
                final all = (statusFilter == 'active'
                    ? source.where((item) => item.isActive).toList()
                    : statusFilter == 'inactive'
                    ? source.where((item) => !item.isActive).toList()
                    : [...source]);
                if (sortColumn != null) {
                  all.sort((a, b) {
                    final result = switch (sortColumn) {
                      2 => a.code.compareTo(b.code),
                      3 => a.name.compareTo(b.name),
                      4 => a.isActive == b.isActive ? 0 : (a.isActive ? 1 : -1),
                      _ => 0,
                    };
                    return sortAscending ? result : -result;
                  });
                }
                final pages = all.isEmpty ? 1 : (all.length / pageSize).ceil();
                final currentPage = page > pages ? pages : page;
                final start = (currentPage - 1) * pageSize;
                final rows = all.skip(start).take(pageSize).toList();
                final firstItem = rows.isEmpty ? 0 : start + 1;
                final lastItem = rows.isEmpty ? 0 : start + rows.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูลตามเงื่อนไข'))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                if (_showCards || constraints.maxWidth < 900) {
                                  return _buildMobileCards(
                                    context,
                                    rows,
                                    start,
                                  );
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    color: preset.surface,
                                    borderRadius: BorderRadius.circular(
                                      LaooRadius.xs,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Theme(
                                      data: Theme.of(
                                        context,
                                      ).copyWith(dividerColor: preset.border),
                                      child: DataTableTheme(
                                        data: DataTableThemeData(
                                          dataRowColor: LaooDataTable.rowColor(
                                            preset.primary,
                                          ),
                                          dataRowMinHeight: 48,
                                          dataRowMaxHeight: 56,
                                          headingTextStyle: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        child: DataTable(
                                          horizontalMargin: 8,
                                          columnSpacing: 20,
                                          dividerThickness: .6,
                                          sortColumnIndex: sortColumn,
                                          sortAscending: sortAscending,
                                          headingRowColor:
                                              WidgetStatePropertyAll(
                                                preset.primary.withValues(
                                                  alpha: .10,
                                                ),
                                              ),
                                          columns: [
                                            DataColumn(
                                              columnWidth:
                                                  LaooDataTable.idColumnWidth,
                                              headingRowAlignment:
                                                  MainAxisAlignment.center,
                                              label: const Text('ID'),
                                            ),
                                            DataColumn(
                                              label: const SizedBox(
                                                width: 120,
                                                child: Center(
                                                  child: Text('Action'),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: const Text(
                                                'รหัสกลุ่มสิทธิ์',
                                              ),
                                              onSort: (column, ascending) =>
                                                  _sort(column, ascending),
                                            ),
                                            DataColumn(
                                              label: const Text('ชื่อกลุ่ม'),
                                              onSort: (column, ascending) =>
                                                  _sort(column, ascending),
                                            ),
                                            DataColumn(
                                              label: const Text('สถานะ'),
                                              onSort: (column, ascending) =>
                                                  _sort(column, ascending),
                                            ),
                                          ],
                                          rows: [
                                            for (
                                              var i = 0;
                                              i < rows.length;
                                              i++
                                            )
                                              DataRow(
                                                cells: [
                                                  DataCell(
                                                    Center(
                                                      child: Text(
                                                        '${start + i + 1}',
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    SizedBox(
                                                      width: 120,
                                                      child: Center(
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (widget.canEdit)
                                                              IconButton(
                                                                onPressed: () =>
                                                                    widget.onEdit(
                                                                      rows[i],
                                                                    ),
                                                                icon: Icon(
                                                                  Icons
                                                                      .edit_outlined,
                                                                  color: preset
                                                                      .primary,
                                                                ),
                                                                tooltip:
                                                                    'แก้ไข',
                                                              ),
                                                            if (widget
                                                                .canDelete)
                                                              IconButton(
                                                                onPressed: () =>
                                                                    widget.onDelete(
                                                                      rows[i],
                                                                    ),
                                                                icon: const Icon(
                                                                  Icons
                                                                      .delete_outline,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                                tooltip: 'ลบ',
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(Text(rows[i].code)),
                                                  DataCell(Text(rows[i].name)),
                                                  DataCell(
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: rows[i].isActive
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                                  .withValues(
                                                                    alpha: .12,
                                                                  )
                                                            : Colors
                                                                  .red
                                                                  .shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        rows[i].isActive
                                                            ? 'เปิด'
                                                            : 'ปิด',
                                                        style: TextStyle(
                                                          color:
                                                              rows[i].isActive
                                                              ? Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary
                                                              : Colors.red,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    WorkspaceSectionCard(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PageButton(
                            label: 'ก่อนหน้า',
                            enabled: currentPage > 1,
                            onTap: () => setState(() => page--),
                          ),
                          for (var i = 1; i <= pages; i++)
                            _PageButton(
                              label: '$i',
                              enabled: i != currentPage,
                              onTap: () => setState(() => page = i),
                              selected: i == currentPage,
                            ),
                          _PageButton(
                            label: 'ถัดไป',
                            enabled: currentPage < pages,
                            onTap: () => setState(() => page++),
                          ),
                          Text('$firstItem-$lastItem จาก ${all.length}'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCards(
    BuildContext context,
    List<RoleGroup> rows,
    int start,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.code,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            (item.isActive ? primary : theme.colorScheme.error)
                                .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          item.isActive ? 'เปิด' : 'ปิด',
                          style: TextStyle(
                            color: item.isActive
                                ? primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (widget.canEdit)
                      IconButton(
                        tooltip: 'แก้ไข',
                        onPressed: () => widget.onEdit(item),
                        icon: Icon(Icons.edit_outlined, color: primary),
                      ),
                    if (widget.canDelete)
                      IconButton(
                        tooltip: 'ลบ',
                        onPressed: () => widget.onDelete(item),
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
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

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final bool enabled, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isPrevious = label == 'ก่อนหน้า';
    final isNext = label == 'ถัดไป';
    final arrow = isPrevious || isNext;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            color: selected
                ? primary
                : arrow
                ? Colors.grey.shade300
                : enabled
                ? Colors.white
                : Colors.grey.shade300,
            border: !arrow && enabled && !selected
                ? Border.all(color: primary)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            child: InkWell(
              onTap: selected || !enabled ? null : onTap,
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              child: Center(
                child: arrow
                    ? Icon(
                        isPrevious ? Icons.chevron_left : Icons.chevron_right,
                        size: 22,
                        color: Colors.grey.shade600,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: LaooTypography.button,
                          color: selected ? Colors.white : primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({
    super.key,
    required this.onCancel,
    required this.onSave,
    required this.favoriteKey,
    this.editing,
    this.loading,
  });
  final VoidCallback onCancel;
  final Future<void> Function(String, String, String, bool) onSave;
  final RoleGroup? editing;
  final bool? loading;
  final String favoriteKey;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController code, name, desc;
  bool active = true;
  @override
  void initState() {
    super.initState();
    final x = widget.editing;
    code = TextEditingController(text: x?.code);
    name = TextEditingController(text: x?.name);
    desc = TextEditingController(text: x?.description);
    active = x?.isActive ?? true;
  }

  void clearFields() {
    code.clear();
    name.clear();
    desc.clear();
    setState(() => active = true);
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SingleChildScrollView(
    padding: const EdgeInsets.all(LaooLayout.cardMargin),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceSectionCard(
          child: WorkspaceActionHeader(
            title:
                'กลุ่มสิทธิ์ > ${widget.editing == null ? 'เพิ่ม' : 'แก้ไข'}',
            favoriteKey: widget.favoriteKey,
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(c).colorScheme.primary,
                  side: BorderSide(color: Theme.of(c).colorScheme.primary),
                ),
                onPressed: widget.onCancel,
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: widget.loading == true
                    ? null
                    : () => widget.onSave(
                        code.text,
                        name.text,
                        desc.text,
                        active,
                      ),
                child: const Text('บันทึก'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: LaooColors.border),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('สถานะ'),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'รหัสกลุ่มสิทธิ์ *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อกลุ่มสิทธิ์ *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'รายละเอียด'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
