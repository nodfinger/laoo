import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../data/master_data_api.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';

class MasterDataPage extends StatefulWidget {
  const MasterDataPage({super.key, required this.menuScope});

  final WorkspaceMenuScope menuScope;

  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterGroup {
  const _MasterGroup(this.code, this.name);
  final String code;
  final String name;
}

class _MasterRow {
  _MasterRow({required this.code, required this.name, required this.seq, this.shortCode = ''});
  String code;
  String name;
  int seq;
  String shortCode;
}

class _MasterDataPageState extends State<MasterDataPage> {
  final _searchController = TextEditingController();
  final _api = MasterDataApi();
  final List<_MasterGroup> _groups = [];
  final Map<String, List<_MasterRow>> _rows = {};
  bool _loading = true;

  String _selectedGroup = '001';
  _MasterRow? _editing;
  String? _message;
  bool _messageError = false;
  int _sortColumn = 4;
  bool _sortAscending = true;
  int _currentPage = 0;
  static const _pageSize = 5;

  _MasterGroup get _group => _groups.firstWhere((item) => item.code == _selectedGroup);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final groups = await _api.groups().timeout(const Duration(seconds: 10));
      if (groups.isEmpty) throw StateError('ไม่พบกลุ่มข้อมูล');
      _groups
        ..clear()
        ..addAll(groups.map((item) => _MasterGroup(item['code'].toString(), item['name'].toString())));
      _selectedGroup = _groups.any((item) => item.code == _selectedGroup) ? _selectedGroup : _groups.first.code;
      await _loadRows();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) setState(() { _loading = false; _message = 'ไม่สามารถโหลดกลุ่มข้อมูลได้ กรุณาตรวจสอบ dbo.TDSTMasterGroup'; _messageError = true; });
    }
  }

  Future<void> _loadRows() async {
    final items = await _api.list(_selectedGroup);
    _rows[_selectedGroup] = items.map((item) => _MasterRow(code: item['code'].toString(), name: item['name'].toString(), seq: (item['seq'] as num?)?.toInt() ?? 0, shortCode: item['shortCode']?.toString() ?? '')).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _api.dispose();
    super.dispose();
  }

  List<_MasterRow> get _filteredRows {
    final term = _searchController.text.trim().toLowerCase();
    final rows = [...(_rows[_selectedGroup] ?? const <_MasterRow>[])]
      ..sort((a, b) {
        final result = switch (_sortColumn) {
          2 => a.code.compareTo(b.code),
          3 => a.name.compareTo(b.name),
          4 => a.seq.compareTo(b.seq),
          5 => a.shortCode.compareTo(b.shortCode),
          _ => a.seq != b.seq ? a.seq.compareTo(b.seq) : a.name.compareTo(b.name),
        };
        return _sortAscending ? result : -result;
      });
    final filtered = term.isEmpty ? rows : rows.where((row) => row.code.toLowerCase().contains(term) || row.name.toLowerCase().contains(term) || row.shortCode.toLowerCase().contains(term)).toList();
    final start = (_currentPage * _pageSize).clamp(0, filtered.length);
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final term = _searchController.text.trim().toLowerCase();
    final count = (_rows[_selectedGroup] ?? const <_MasterRow>[]).where((row) => term.isEmpty || row.code.toLowerCase().contains(term) || row.name.toLowerCase().contains(term) || row.shortCode.toLowerCase().contains(term)).length;
    return count == 0 ? 1 : (count / _pageSize).ceil();
  }

  int get _filteredCount {
    final term = _searchController.text.trim().toLowerCase();
    return (_rows[_selectedGroup] ?? const <_MasterRow>[]).where((row) => term.isEmpty || row.code.toLowerCase().contains(term) || row.name.toLowerCase().contains(term) || row.shortCode.toLowerCase().contains(term)).length;
  }

  void _sort(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _sortAscending = ascending;
        _currentPage = 0;
      });

  void _selectGroup(String? value) {
    if (value == null) return;
    setState(() {
      _selectedGroup = value;
      _searchController.clear();
      _editing = null;
      _currentPage = 0;
    });
    _loadRows().then((_) { if (mounted) setState(() {}); }).catchError((error) { if (mounted) setState(() { _message = error.toString(); _messageError = true; }); });
  }

  void _startAdd() {
    final next = ((_rows[_selectedGroup]?.length ?? 0) + 1).toString().padLeft(5, '0');
    setState(() => _editing = _MasterRow(code: next, name: '', seq: (_rows[_selectedGroup]?.length ?? 0) + 1));
  }

  void _startEdit(_MasterRow row) => setState(() => _editing = row);

  Future<void> _delete(_MasterRow row) async {
    try {
      await _api.delete(_selectedGroup, row.code);
    } catch (error) {
      if (mounted) setState(() { _message = error.toString(); _messageError = true; });
      return;
    }
    setState(() {
      _rows[_selectedGroup]?.remove(row);
      if (_currentPage >= _totalPages) {
        _currentPage = (_totalPages - 1).clamp(0, _totalPages);
      }
      _message = 'ลบข้อมูล ${row.name} สำเร็จ';
      _messageError = false;
    });
  }

  Future<void> _save(_MasterRow row) async {
    final name = row.name.trim();
    final duplicate = (_rows[_selectedGroup] ?? const <_MasterRow>[]).any((item) => item != row && item.name.trim().toLowerCase() == name.toLowerCase());
    if (name.isEmpty || duplicate) {
      setState(() {
        _message = name.isEmpty ? 'กรุณาระบุ Name' : 'Name ซ้ำกับข้อมูลเดิม';
        _messageError = true;
      });
      return;
    }
    try {
      final body = {'code': row.code, 'name': name, 'seq': row.seq, 'shortCode': row.shortCode.trim()};
      if ((_rows[_selectedGroup] ?? const <_MasterRow>[]).contains(row)) {
        await _api.update(_selectedGroup, row.code, body);
      } else {
        await _api.create(_selectedGroup, body);
      }
      await _loadRows();
    } catch (error) {
      if (mounted) setState(() { _message = error.toString(); _messageError = true; });
      return;
    }
    setState(() {
      _editing = null;
      _message = 'บันทึกข้อมูลกลุ่ม${_group.name}สำเร็จ';
      _messageError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SupportWorkspaceShell(menuScope: widget.menuScope, pageTitle: 'รหัสพื้นฐาน', activeMenu: 'masterData', child: const Center(child: CircularProgressIndicator()));
    }
    if (_groups.isEmpty) {
      return SupportWorkspaceShell(
        menuScope: widget.menuScope,
        pageTitle: 'รหัสพื้นฐาน',
        activeMenu: 'masterData',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(_message ?? 'ไม่สามารถโหลดกลุ่มข้อมูลได้', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }
    final editing = _editing;
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: editing == null ? 'รหัสพื้นฐาน' : 'รหัสพื้นฐาน > ${editing.code == '' ? 'เพิ่ม' : 'แก้ไข'}',
      activeMenu: 'masterData',
      child: editing == null ? _buildList(context) : _buildForm(context, editing),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(child: Row(children: [
            Text('รหัสพื้นฐาน', style: TextStyle(fontSize: LaooTypography.workspaceCaption, fontWeight: LaooTypography.workspaceCaptionWeight, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Text('กำลังทำข้อมูล ${_group.name}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
          ])),
          FilledButton.icon(onPressed: _startAdd, icon: const Icon(Icons.add), label: const Text('เพิ่ม')),
        ]),
        if (_message != null) ...[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(_message!),
            leading: Icon(_messageError ? Icons.error_outline : Icons.check_circle_outline, color: _messageError ? theme.colorScheme.error : theme.colorScheme.primary),
            backgroundColor: (_messageError ? theme.colorScheme.error : theme.colorScheme.primary).withValues(alpha: .08),
            actions: [TextButton(onPressed: () => setState(() => _message = null), child: const Text('ปิด'))],
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              Expanded(child: TextField(controller: _searchController, onChanged: (_) => setState(() => _currentPage = 0), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'ค้นหารหัสหรือชื่อ'))),
              const SizedBox(width: 14),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  value: _selectedGroup,
                  decoration: const InputDecoration(labelText: 'กลุ่มข้อมูล'),
                  items: _groups.map((item) => DropdownMenuItem(value: item.code, child: Text('${item.code} - ${item.name}'))).toList(),
                  onChanged: _selectGroup,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
              border: TableBorder(top: BorderSide(color: theme.dividerColor, width: .25), bottom: BorderSide(color: theme.dividerColor, width: .25), horizontalInside: BorderSide(color: theme.dividerColor.withValues(alpha: .7), width: .25)),
              headingRowColor: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest.withValues(alpha: .65)),
              headingTextStyle: TextStyle(fontSize: LaooTypography.tableHeader, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
              dataTextStyle: TextStyle(fontSize: LaooTypography.tableBody, color: theme.colorScheme.onSurface),
              columns: [
                const DataColumn(label: Text('ID')),
                const DataColumn(label: SizedBox(width: 100, child: Center(child: Text('Action')))),
                DataColumn(label: const Text('รหัส'), onSort: _sort),
                DataColumn(label: const Text('ชื่อ'), onSort: _sort),
                DataColumn(label: const Text('เรียงลำดับแสดง'), onSort: _sort),
                DataColumn(label: const Text('รหัสย่อ'), onSort: _sort),
              ],
              rows: _filteredRows.asMap().entries.map((entry) {
                final row = entry.value;
                return DataRow(cells: [
                  DataCell(Text('${entry.key + 1}')),
                  DataCell(SizedBox(width: 100, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'แก้ไข', onPressed: () => _startEdit(row), icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary)), IconButton(tooltip: 'ลบ', onPressed: () => _delete(row), icon: const Icon(Icons.delete_outline, color: Colors.red))])))),
                  DataCell(Text(row.code)), DataCell(Text(row.name)), DataCell(Text('${row.seq}')), DataCell(Text(row.shortCode)),
                ]);
              }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PaginationBar(page: _currentPage, totalPages: _totalPages, totalItems: _filteredCount, pageSize: _pageSize, onChanged: (page) => setState(() => _currentPage = page)),
      ],
    );
  }

  Widget _buildForm(BuildContext context, _MasterRow row) {
    return _MasterDataForm(row: row, groupName: _group.name, onCancel: () => setState(() => _editing = null), onSave: () => _save(row));
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.page, required this.totalPages, required this.totalItems, required this.pageSize, required this.onChanged});

  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final start = totalItems == 0 ? 0 : page * pageSize + 1;
    final end = totalItems == 0 ? 0 : (start + pageSize - 1).clamp(0, totalItems);
    final outline = OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: BorderSide(color: accent.withValues(alpha: .45)),
      minimumSize: const Size(66, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        OutlinedButton(onPressed: page > 0 ? () => onChanged(page - 1) : null, style: outline, child: const Text('ก่อนหน้า')),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          height: 32,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: const CircleBorder()),
            child: Text('${page + 1}'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: page + 1 < totalPages ? () => onChanged(page + 1) : null, style: outline, child: const Text('ถัดไป')),
        const SizedBox(width: 12),
        Text('แสดง $start-$end จาก $totalItems รายการ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: LaooTypography.tableBody)),
      ],
    );
  }
}

class _MasterDataForm extends StatefulWidget {
  const _MasterDataForm({required this.row, required this.groupName, required this.onCancel, required this.onSave});
  final _MasterRow row;
  final String groupName;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  State<_MasterDataForm> createState() => _MasterDataFormState();
}

class _MasterDataFormState extends State<_MasterDataForm> {
  late final TextEditingController _name;
  late final TextEditingController _seq;
  late final TextEditingController _shortCode;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.row.name);
    _seq = TextEditingController(text: '${widget.row.seq}');
    _shortCode = TextEditingController(text: widget.row.shortCode);
    widget.row.name = _name.text;
    widget.row.seq = int.tryParse(_seq.text) ?? 1;
    widget.row.shortCode = _shortCode.text;
  }

  @override
  void dispose() {
    _name.dispose(); _seq.dispose(); _shortCode.dispose(); super.dispose();
  }

  void _sync() {
    widget.row.name = _name.text;
    widget.row.seq = int.tryParse(_seq.text) ?? 1;
    widget.row.shortCode = _shortCode.text.trim();
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(children: [const Expanded(child: Text('รหัสพื้นฐาน > เพิ่ม/แก้ไข', style: TextStyle(fontSize: LaooTypography.workspaceCaption, fontWeight: LaooTypography.workspaceCaptionWeight))), OutlinedButton(onPressed: widget.onCancel, child: const Text('ยกเลิก')), const SizedBox(width: 10), FilledButton.icon(onPressed: _sync, icon: const Icon(Icons.save_outlined), label: const Text('บันทึก'))]),
          const SizedBox(height: 8),
          Text('กลุ่มข้อมูล: ${widget.groupName}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            TextFormField(initialValue: widget.row.code, readOnly: true, decoration: const InputDecoration(labelText: 'MasterCode (Run Auto)')),
            const SizedBox(height: 12),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 12),
            TextFormField(controller: _seq, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seq')),
            const SizedBox(height: 12),
            TextFormField(controller: _shortCode, decoration: const InputDecoration(labelText: 'ShortCode')),
          ]))),
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [OutlinedButton(onPressed: widget.onCancel, child: const Text('ยกเลิก')), const SizedBox(width: 10), FilledButton.icon(onPressed: _sync, icon: const Icon(Icons.save_outlined), label: const Text('บันทึก'))])),
        ],
      ),
    );
  }
}
