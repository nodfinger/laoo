import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

class ServiceRequestSubjectPage extends StatefulWidget {
  const ServiceRequestSubjectPage({
    super.key,
    this.api,
    this.embedded = false,
    this.onSelected,
  });
  final ApiClient? api;
  final bool embedded;
  final ValueChanged<String>? onSelected;
  @override
  State<ServiceRequestSubjectPage> createState() =>
      _ServiceRequestSubjectPageState();
}

class _ServiceRequestSubjectPageState extends State<ServiceRequestSubjectPage> {
  late final _api = widget.api ?? ApiClient();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _actions = {};
  bool _loading = true, _cards = false;
  String _approvalFilter = 'all';
  String? _error;
  int _page = 1;
  static const _size = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final actions = await _api.get('/api/service/request-subjects/actions');
      if (actions is! Map || actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์แสดงข้อมูล');
      }
      final rows = await _api.get(
        '/api/service/request-subjects',
        query: {
          'search': _search.text.trim(),
          if (_approvalFilter != 'all') 'requiresApproval': _approvalFilter,
        },
      );
      if (mounted) {
        setState(() {
          _actions = Map<String, dynamic>.from(actions);
          _rows = (rows as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _page = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'ไม่สามารถโหลดหัวข้อแจ้งซ่อมได้ กรุณาตรวจสอบสิทธิ์และลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(BuildContext context, [Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubjectDialog(api: _api, row: row),
    );
    if (saved == true && mounted && context.mounted) {
      showTimedSnackBar(context, message: 'บันทึกหัวข้อแจ้งซ่อมเรียบร้อยแล้ว');
      await _load();
    }
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: BorderSide(color: Theme.of(dialog).colorScheme.error),
        ),
        title: const Text(
          'ลบหัวข้อแจ้งซ่อม',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text('ต้องการลบ ${row['name']} หรือไม่'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialog, false),
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialog).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete('/api/service/request-subjects/${row['id']}');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'ไม่สามารถลบหัวข้อได้ กรุณาลองใหม่');
    }
  }

  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  Widget _rowActions(BuildContext context, Map<String, dynamic> row) {
    final colors = Theme.of(context).colorScheme;
    final canEdit = row['isShared'] != true && _actions['edit'] == true;
    final canDelete = row['isShared'] != true && _actions['delete'] == true;
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: canEdit ? 'แก้ไข' : 'ไม่มีสิทธิ์แก้ไข',
          icon: Icon(
            canEdit ? Icons.edit_outlined : Icons.lock_outline,
            color: canEdit ? colors.primary : colors.onSurfaceVariant,
          ),
          onPressed: canEdit ? () => _edit(context, row) : null,
        ),
        IconButton(
          tooltip: canDelete ? 'ลบ' : 'ไม่มีสิทธิ์ลบ',
          icon: Icon(
            canDelete ? Icons.delete_outline : Icons.lock_outline,
            color: canDelete ? colors.error : colors.onSurfaceVariant,
          ),
          onPressed: canDelete ? () => _delete(context, row) : null,
        ),
      ],
    );
  }

  Widget _statusBadge(BuildContext context, bool active) {
    final colors = Theme.of(context).colorScheme;
    final color = active ? colors.primary : colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _pageButton(
    BuildContext context, {
    IconData? icon,
    String? text,
    VoidCallback? onPressed,
    bool current = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final enabled = current || onPressed != null;
    return SizedBox(
      width: LaooLayout.paginationButtonSize,
      height: LaooLayout.paginationButtonSize,
      child: FilledButton(
        onPressed: current ? () {} : onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 22)
            : Text(
                text ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: enabled ? colors.onPrimary : null,
                ),
              ),
      ),
    );
  }

  Widget _rowsView(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    int start,
  ) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_cards || constraints.maxWidth < 700) {
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                onTap: widget.onSelected != null && row['isActive'] == true
                    ? () => widget.onSelected!(row['code'].toString())
                    : null,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.topic_outlined, color: colors.primary),
                title: Text('${row['name'] ?? '-'}'),
                subtitle: Text(
                  row['requiresApproval'] == true
                      ? 'ต้องขออนุมัติก่อนดำเนินการ'
                      : 'ไม่ต้องขออนุมัติ',
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statusBadge(context, row['isActive'] == true),
                    _rowActions(context, row),
                  ],
                ),
              );
            },
          );
        }
        Widget cell(Widget value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: value,
        );
        Widget selectCell(Map<String, dynamic> row, Widget value) => InkWell(
          onTap: widget.onSelected != null && row['isActive'] == true
              ? () => widget.onSelected!(row['code'].toString())
              : null,
          child: cell(value),
        );
        return SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(42),
              1: FixedColumnWidth(112),
              2: FlexColumnWidth(3),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.5),
              6: FlexColumnWidth(1.5),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                ),
                children: [
                  for (final title in [
                    'ID',
                    'Action',
                    'ชื่อหัวข้อ',
                    'ลำดับ',
                    'รหัสย่อ',
                    'การอนุมัติ',
                    'สถานะ',
                  ])
                    cell(
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              for (final (index, row) in rows.indexed)
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colors.outlineVariant,
                        width: .6,
                      ),
                    ),
                  ),
                  children: [
                    selectCell(row, Text('${start + index + 1}')),
                    cell(_rowActions(context, row)),
                    selectCell(row, Text('${row['name'] ?? '-'}')),
                    selectCell(row, Text('${row['seq'] ?? 0}')),
                    selectCell(row, Text('${row['shortCode'] ?? '-'}')),
                    selectCell(
                      row,
                      Text(
                        row['requiresApproval'] == true
                            ? 'ต้องอนุมัติ'
                            : 'ไม่ต้องอนุมัติ',
                      ),
                    ),
                    selectCell(
                      row,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _statusBadge(context, row['isActive'] == true),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Builder(
      builder: (context) {
        final color = Theme.of(context).colorScheme.primary;
        final start = (_page - 1) * _size;
        final pageRows = _rows.skip(start).take(_size).toList();
        final pages = _rows.isEmpty ? 1 : (_rows.length / _size).ceil();
        return Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _surface(
                Row(
                  children: [
                    const Expanded(
                      child: WorkspacePageTitle(
                        title: 'หัวข้อแจ้งซ่อม',
                        favoriteKey: '18002',
                      ),
                    ),
                    if (MediaQuery.sizeOf(context).width >= 700) ...[
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          tooltip: _cards ? 'แสดงแบบตาราง' : 'แสดงแบบการ์ด',
                          onPressed: () => setState(() => _cards = !_cards),
                          style: IconButton.styleFrom(
                            backgroundColor: color.withValues(alpha: .1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          icon: Icon(
                            _cards ? Icons.view_list : Icons.grid_view,
                            color: color,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_actions['create'] == true)
                      FilledButton.icon(
                        onPressed: () => _edit(context),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _surface(
                FilterHeightSync(
                  builder: (context, key, height) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          key: key,
                          controller: _search,
                          onSubmitted: (_) => _load(),
                          decoration: const InputDecoration(
                            labelText: 'ค้นหาหัวข้อ',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        style: filterActionHeightStyle(height),
                        onPressed: _load,
                        icon: const Icon(Icons.search),
                        label: const Text('ค้นหา'),
                      ),
                      OutlinedButton.icon(
                        style: filterActionHeightStyle(height),
                        onPressed: () {
                          _search.clear();
                          setState(() => _approvalFilter = 'all');
                          _load();
                        },
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('ล้าง Filter'),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _approvalFilter,
                          decoration: const InputDecoration(
                            labelText: 'การอนุมัติ',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('ทั้งหมด'),
                            ),
                            DropdownMenuItem(
                              value: 'true',
                              child: Text('ต้องอนุมัติ'),
                            ),
                            DropdownMenuItem(
                              value: 'false',
                              child: Text('ไม่ต้องอนุมัติ'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _approvalFilter = v ?? 'all'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                _surface(
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: _surface(
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : pageRows.isEmpty
                      ? const Center(child: Text('ไม่พบหัวข้อแจ้งซ่อม'))
                      : _rowsView(context, pageRows, start),
                ),
              ),
              const SizedBox(height: 8),
              _surface(
                SizedBox(
                  height:
                      LaooLayout.paginationCardHeight -
                      2 * LaooLayout.cardPadding,
                  child: Row(
                    children: [
                      _pageButton(
                        context,
                        icon: Icons.chevron_left,
                        onPressed: _page > 1
                            ? () => setState(() => _page--)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      _pageButton(context, text: '$_page', current: true),
                      const SizedBox(width: 6),
                      _pageButton(
                        context,
                        icon: Icons.chevron_right,
                        onPressed: _page < pages
                            ? () => setState(() => _page++)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _rows.isEmpty
                            ? '0-0 จาก 0'
                            : '${start + 1}-${start + pageRows.length} จาก ${_rows.length}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (widget.embedded) return content;
    return SupportWorkspaceShell(
      pageTitle: 'หัวข้อแจ้งซ่อม',
      activeMenu: 'serviceRequestSubjects',
      menuScope: WorkspaceMenuScope.company,
      child: content,
    );
  }
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({required this.api, this.row});
  final ApiClient api;
  final Map<String, dynamic>? row;
  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.row?['name']?.toString() ?? '',
  );
  late final _seq = TextEditingController(
    text: (widget.row?['seq'] ?? 1).toString(),
  );
  late final _short = TextEditingController(
    text: widget.row?['shortCode']?.toString() ?? '',
  );
  late bool _active = widget.row?['isActive'] != false;
  late bool _requiresApproval = widget.row?['requiresApproval'] == true;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _seq.dispose();
    _short.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'seq': int.parse(_seq.text),
      'shortCode': _short.text.trim(),
      'isActive': _active,
      'requiresApproval': _requiresApproval,
    };
    try {
      if (widget.row == null) {
        await widget.api.post('/api/service/request-subjects', body: body);
      } else {
        await widget.api.put(
          '/api/service/request-subjects/${widget.row!['id']}',
          body: body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    title: Row(
      children: [
        Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'หัวข้อแจ้งซ่อม > ${widget.row == null ? 'เพิ่ม' : 'แก้ไข'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Row(
                children: [
                  const Text('สถานะ'),
                  Switch(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _requiresApproval,
                onChanged: (v) =>
                    setState(() => _requiresApproval = v ?? false),
                title: const Text('ต้องขออนุมัติก่อนดำเนินการ'),
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              TextFormField(
                controller: _name,
                maxLength: 500,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'ชื่อหัวข้อ *',
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'กรุณาระบุชื่อหัวข้อ'
                    : null,
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              TextFormField(
                controller: _seq,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(labelText: 'ลำดับแสดงข้อมูล'),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'กรุณาระบุตัวเลข' : null,
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              TextFormField(
                controller: _short,
                maxLength: 100,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'รหัสย่อ',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      OutlinedButton.icon(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        icon: const Icon(Icons.close),
        label: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}
