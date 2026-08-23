import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/combo_box_text.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/timed_snack_bar.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../data/master_data_api.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}

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
  _MasterRow({
    required this.code,
    required this.name,
    required this.seq,
    this.shortCode = '',
  });
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
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;

  String _selectedGroup = '001';
  _MasterRow? _editing;
  bool _isAdding = false;
  String? _message;
  bool _messageError = false;
  int _sortColumn = 4;
  bool _sortAscending = true;
  int _currentPage = 0;
  String _appliedSearch = '';

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 50;

  _MasterGroup get _group =>
      _groups.firstWhere((item) => item.code == _selectedGroup);

  @override
  void initState() {
    super.initState();
    _loadActions();
    _load();
  }

  Future<void> _loadActions() async {
    try {
      final permissions = await _api.actions();
      if (!mounted) return;
      setState(() {
        _canCreate = permissions['create'] == true;
        _canEdit = permissions['edit'] == true;
        _canDelete = permissions['delete'] == true;
      });
    } catch (_) {}
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
        ..addAll(
          groups.map(
            (item) =>
                _MasterGroup(item['code'].toString(), item['name'].toString()),
          ),
        );
      _selectedGroup = _groups.any((item) => item.code == _selectedGroup)
          ? _selectedGroup
          : _groups.first.code;
      await _loadRows();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'ไม่สามารถโหลดกลุ่มข้อมูลได้ กรุณาตรวจสอบ dbo.TDSTMasterGroup';
          _messageError = true;
        });
      }
    }
  }

  Future<void> _loadRows() async {
    final items = await _api.list(_selectedGroup);
    _rows[_selectedGroup] = items
        .map(
          (item) => _MasterRow(
            code: item['code'].toString(),
            name: item['name'].toString(),
            seq: (item['seq'] as num?)?.toInt() ?? 0,
            shortCode: item['shortCode']?.toString() ?? '',
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _api.dispose();
    super.dispose();
  }

  void _dismissMessage() {
    if (mounted) setState(() => _message = null);
  }

  List<_MasterRow> get _filteredRows {
    final term = _appliedSearch;
    final rows = [...(_rows[_selectedGroup] ?? const <_MasterRow>[])]
      ..sort((a, b) {
        final result = switch (_sortColumn) {
          2 => a.code.compareTo(b.code),
          3 => a.name.compareTo(b.name),
          4 => a.seq.compareTo(b.seq),
          5 => a.shortCode.compareTo(b.shortCode),
          _ =>
            a.seq != b.seq ? a.seq.compareTo(b.seq) : a.name.compareTo(b.name),
        };
        return _sortAscending ? result : -result;
      });
    final filtered = term.isEmpty
        ? rows
        : rows
              .where(
                (row) =>
                    row.code.toLowerCase().contains(term) ||
                    row.name.toLowerCase().contains(term) ||
                    row.shortCode.toLowerCase().contains(term),
              )
              .toList();
    final start = (_currentPage * _pageSize).clamp(0, filtered.length);
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final term = _appliedSearch;
    final count = (_rows[_selectedGroup] ?? const <_MasterRow>[])
        .where(
          (row) =>
              term.isEmpty ||
              row.code.toLowerCase().contains(term) ||
              row.name.toLowerCase().contains(term) ||
              row.shortCode.toLowerCase().contains(term),
        )
        .length;
    return count == 0 ? 1 : (count / _pageSize).ceil();
  }

  int get _filteredCount {
    final term = _appliedSearch;
    return (_rows[_selectedGroup] ?? const <_MasterRow>[])
        .where(
          (row) =>
              term.isEmpty ||
              row.code.toLowerCase().contains(term) ||
              row.name.toLowerCase().contains(term) ||
              row.shortCode.toLowerCase().contains(term),
        )
        .length;
  }

  void _sort(int column, bool ascending) => setState(() {
    _sortColumn = column;
    _sortAscending = ascending;
    _currentPage = 0;
  });

  void _applySearch() {
    setState(() {
      _appliedSearch = _searchController.text.trim().toLowerCase();
      _currentPage = 0;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _appliedSearch = '';
      _currentPage = 0;
    });
  }

  void _selectGroup(String? value) {
    if (value == null) return;
    setState(() {
      _selectedGroup = value;
      _searchController.clear();
      _appliedSearch = '';
      _editing = null;
      _currentPage = 0;
    });
    _loadRows()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _message = error.toString();
              _messageError = true;
            });
          }
        });
  }

  void _startAdd() {
    final next = ((_rows[_selectedGroup]?.length ?? 0) + 1).toString().padLeft(
      5,
      '0',
    );
    setState(() {
      _isAdding = true;
      _editing = _MasterRow(
        code: next,
        name: '',
        seq: (_rows[_selectedGroup]?.length ?? 0) + 1,
      );
    });
  }

  void _startEdit(_MasterRow row) => setState(() {
    _isAdding = false;
    _editing = row;
  });

  Future<void> _delete(_MasterRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final red = Theme.of(context).colorScheme.error;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: red, width: 1.5),
          ),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: red.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.delete_outline, color: red),
          ),
          title: Text(
            'ยืนยันการลบข้อมูล',
            style: TextStyle(color: red, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: red.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('ต้องการลบ ${row.code} - ${row.name} หรือไม่?'),
              ),
              const SizedBox(height: 12),
              Text(
                'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: red),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _api.delete(_selectedGroup, row.code);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _messageError = true;
        });
      }
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
    String normalize(String value) =>
        value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final duplicate = (_rows[_selectedGroup] ?? const <_MasterRow>[]).any(
      (item) => item != row && normalize(item.name) == normalize(name),
    );
    if (name.isEmpty || duplicate) {
      setState(() {
        _message = name.isEmpty ? 'กรุณาระบุ Name' : 'Name ซ้ำกับข้อมูลเดิม';
        _messageError = true;
      });
      throw StateError(name.isEmpty ? 'กรุณาระบุชื่อ' : 'ชื่อซ้ำกับข้อมูลเดิม');
    }
    final adding = !(_rows[_selectedGroup] ?? const <_MasterRow>[]).contains(
      row,
    );
    try {
      final body = {
        'code': row.code,
        'name': name,
        'seq': row.seq,
        'shortCode': row.shortCode.trim(),
      };
      if ((_rows[_selectedGroup] ?? const <_MasterRow>[]).contains(row)) {
        await _api.update(_selectedGroup, row.code, body);
      } else {
        await _api.create(_selectedGroup, body);
      }
      await _loadRows();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _messageError = true;
        });
      }
      rethrow;
    }
    setState(() {
      if (adding) {
        final next = ((_rows[_selectedGroup]?.length ?? 0) + 1)
            .toString()
            .padLeft(5, '0');
        _isAdding = true;
        _editing = _MasterRow(
          code: next,
          name: '',
          seq: (_rows[_selectedGroup]?.length ?? 0) + 1,
        );
      } else {
        _editing = null;
      }
      _message = 'บันทึกข้อมูลกลุ่ม${_group.name}สำเร็จ';
      _messageError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SupportWorkspaceShell(
        menuScope: widget.menuScope,
        pageTitle: 'รหัสพื้นฐาน',
        activeMenu: 'masterData',
        child: const Center(child: CircularProgressIndicator()),
      );
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
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _message ?? 'ไม่สามารถโหลดกลุ่มข้อมูลได้',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }
    final editing = _editing;
    return SupportWorkspaceShell(
      menuScope: widget.menuScope,
      pageTitle: editing == null
          ? 'รหัสพื้นฐาน > ${_group.name}'
          : 'รหัสพื้นฐาน > ${_isAdding ? 'เพิ่ม' : 'แก้ไข'}',
      activeMenu: 'masterData',
      child: Stack(
        children: [
          editing == null ? _buildList(context) : _buildForm(context, editing),
          if (_message != null)
            Positioned(
              top: 12,
              right: 24,
              child: AutoDismissMessage(
                key: ValueKey(_message),
                message: _message!,
                error: _messageError,
                onClose: _dismissMessage,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    final accent = workspaceThemeController.value.primary;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final title = WorkspacePageTitle(
              title: 'รหัสพื้นฐาน > ${_group.name}',
              favoriteKey: '05002',
            );
            final addButton = _canCreate
                ? FilledButton.icon(
                    onPressed: _startAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        100,
                        LaooTypography.buttonHeight,
                      ),
                      alignment: Alignment.center,
                    ),
                  )
                : null;

            if (compact) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  if (addButton != null) ...[
                    const SizedBox(width: 10),
                    addButton,
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: title),
                if (addButton != null) addButton,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final search = TextField(
              controller: _searchController,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'ค้นหารหัสหรือชื่อ',
                suffixIcon: IconButton(
                  tooltip: 'ค้นหา',
                  onPressed: _applySearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            );
            final group = DropdownButtonFormField<String>(
              initialValue: _selectedGroup,
              decoration: const InputDecoration(labelText: 'กลุ่มข้อมูล'),
              items: _groups
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.code,
                      child: LaooComboBoxText('${item.code} - ${item.name}'),
                    ),
                  )
                  .toList(),
              onChanged: _selectGroup,
            );
            final searchButton = FilledButton.icon(
              onPressed: _applySearch,
              icon: const Icon(Icons.search),
              label: const Text('ค้นหา'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
            );
            final clearButton = OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('ล้าง Filter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: searchButton),
                      const SizedBox(width: 8),
                      Expanded(child: clearButton),
                    ],
                  ),
                  const SizedBox(height: 10),
                  group,
                ],
              );
            }

            return Row(
              children: [
                SizedBox(width: 280, child: search),
                const SizedBox(width: 8),
                searchButton,
                const SizedBox(width: 8),
                clearButton,
                const SizedBox(width: 14),
                SizedBox(width: 280, child: group),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildMobileCards(context);
            }

            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                  sortColumnIndex: _sortColumn,
                  sortAscending: _sortAscending,
                  border: TableBorder(
                    top: BorderSide(color: theme.dividerColor, width: .5),
                    bottom: BorderSide(color: theme.dividerColor, width: .5),
                    horizontalInside: BorderSide(
                      color: theme.dividerColor,
                      width: .25,
                    ),
                  ),
                  headingRowColor: WidgetStatePropertyAll(
                    accent.withValues(alpha: .10),
                  ),
                  headingTextStyle: TextStyle(
                    fontSize: LaooTypography.tableHeader,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                  dataTextStyle: TextStyle(
                    fontSize: LaooTypography.tableBody,
                    color: theme.colorScheme.onSurface,
                  ),
                  columns: [
                    const DataColumn(label: Text('ID')),
                    const DataColumn(
                      label: SizedBox(
                        width: 100,
                        child: Center(child: Text('Action')),
                      ),
                    ),
                    DataColumn(label: const Text('รหัส'), onSort: _sort),
                    DataColumn(label: const Text('ชื่อ'), onSort: _sort),
                    DataColumn(
                      label: const Text('เรียงลำดับแสดง'),
                      onSort: _sort,
                    ),
                    DataColumn(label: const Text('รหัสย่อ'), onSort: _sort),
                  ],
                  rows: _filteredRows.asMap().entries.map((entry) {
                    final row = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text('${(_currentPage * _pageSize) + entry.key + 1}'),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_canEdit)
                                    IconButton(
                                      tooltip: 'แก้ไข',
                                      onPressed: () => _startEdit(row),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: accent,
                                      ),
                                    ),
                                  if (_canDelete)
                                    IconButton(
                                      tooltip: 'ลบ',
                                      onPressed: () => _delete(row),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(row.code)),
                        DataCell(Text(row.name)),
                        DataCell(Text('${row.seq}')),
                        DataCell(Text(row.shortCode)),
                      ],
                    );
                  }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _PaginationBar(
          page: _currentPage,
          totalPages: _totalPages,
          totalItems: _filteredCount,
          pageSize: _pageSize,
          onChanged: (page) => setState(() => _currentPage = page),
        ),
      ],
    );
  }

  Widget _buildMobileCards(BuildContext context) {
    final theme = Theme.of(context);
    final accent = workspaceThemeController.value.primary;
    final rows = _filteredRows;
    if (rows.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: .14),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'ไม่พบข้อมูล',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Column(
      children: rows.asMap().entries.map((entry) {
        final row = entry.value;
        final number = (_currentPage * _pageSize) + entry.key + 1;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: .14),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ลำดับแสดง: ${row.seq}  |  ID $number  |  ${row.code}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        row.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (row.shortCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'รหัสย่อ: ${row.shortCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_canEdit || _canDelete)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_canEdit)
                        IconButton(
                          tooltip: 'แก้ไข',
                          onPressed: () => _startEdit(row),
                          icon: Icon(
                            Icons.edit_outlined,
                            color: accent,
                          ),
                        ),
                      if (_canDelete)
                        IconButton(
                          tooltip: 'ลบ',
                          onPressed: () => _delete(row),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildForm(BuildContext context, _MasterRow row) {
    return _MasterDataForm(
      row: row,
      groupName: _group.name,
      isAdding: _isAdding,
      message: _message,
      messageError: _messageError,
      onDismissMessage: _dismissMessage,
      onCancel: () => setState(() => _editing = null),
      onSave: () => _save(row),
      canSave: _isAdding ? _canCreate : _canEdit,
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : page * pageSize + 1;
    final end = totalItems == 0
        ? 0
        : (start + pageSize - 1).clamp(0, totalItems);
    final pageIndexes =
        totalPages <= 7
              ? List<int>.generate(totalPages, (index) => index)
              : <int>{
                  0,
                  (page - 1).clamp(1, totalPages - 2),
                  page,
                  (page + 1).clamp(1, totalPages - 2),
                  totalPages - 1,
                }.toList()
          ..sort();
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _arrowButton(
          context,
          Icons.chevron_left_rounded,
          page > 0 ? () => onChanged(page - 1) : null,
        ),
        for (var index = 0; index < pageIndexes.length; index++) ...[
          if (index > 0 && pageIndexes[index] > pageIndexes[index - 1] + 1)
            const Text('...'),
          _pageButton(context, pageIndexes[index], page),
        ],
        _arrowButton(
          context,
          Icons.chevron_right_rounded,
          page + 1 < totalPages ? () => onChanged(page + 1) : null,
        ),
        Text(
          '$start-$end จาก $totalItems',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: LaooTypography.tableBody,
          ),
        ),
      ],
    );
  }

  Widget _arrowButton(
    BuildContext context,
    IconData icon,
    VoidCallback? onPressed,
  ) => SizedBox(
    width: 34,
    height: 34,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      child: Icon(icon, size: 20),
    ),
  );

  Widget _pageButton(BuildContext context, int index, int currentPage) =>
      SizedBox(
        width: 34,
        height: 34,
        child: index == currentPage
            ? FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: Text('${index + 1}'),
              )
            : OutlinedButton(
                onPressed: () => onChanged(index),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: Text('${index + 1}'),
              ),
      );
}

class _MasterDataForm extends StatefulWidget {
  const _MasterDataForm({
    required this.row,
    required this.groupName,
    required this.isAdding,
    this.message,
    this.messageError = false,
    required this.onDismissMessage,
    required this.onCancel,
    required this.onSave,
    required this.canSave,
  });
  final _MasterRow row;
  final String groupName;
  final bool isAdding;
  final String? message;
  final bool messageError;
  final VoidCallback onDismissMessage;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;
  final bool canSave;

  @override
  State<_MasterDataForm> createState() => _MasterDataFormState();
}

class _MasterDataFormState extends State<_MasterDataForm> {
  late final TextEditingController _name;
  late final TextEditingController _seq;
  late final TextEditingController _shortCode;
  bool _saving = false;

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
    _name.dispose();
    _seq.dispose();
    _shortCode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MasterDataForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row) {
      _name.text = widget.row.name;
      _seq.text = '${widget.row.seq}';
      _shortCode.text = widget.row.shortCode;
    }
  }

  Future<void> _sync() async {
    if (_name.text.trim().isEmpty) {
      showTimedSnackBar(context, message: 'กรุณาระบุชื่อ', error: true);
      return;
    }
    widget.row.name = _name.text;
    widget.row.seq = int.tryParse(_seq.text) ?? 1;
    final normalizedShortCode = _shortCode.text.trim().toUpperCase();
    _shortCode.value = _shortCode.value.copyWith(
      text: normalizedShortCode,
      selection: TextSelection.collapsed(offset: normalizedShortCode.length),
    );
    widget.row.shortCode = normalizedShortCode;
    setState(() => _saving = true);
    try {
      await widget.onSave();
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: WorkspacePageTitle(
                  title:
                      'รหัสพื้นฐาน > ${widget.groupName} > ${widget.isAdding ? 'เพิ่ม' : 'แก้ไข'}',
                  favoriteKey: '05002',
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, LaooTypography.buttonHeight),
                  alignment: Alignment.center,
                ),
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('ยกเลิก'),
              ),
              const SizedBox(width: 10),
              if (widget.canSave)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(100, LaooTypography.buttonHeight),
                    alignment: Alignment.center,
                  ),
                  onPressed: _saving ? null : _sync,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: widget.row.code,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'รหัส (สร้างอัตโนมัติ)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'ชื่อ *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _seq,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ลำดับแสดงข้อมูล',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shortCode,
                    inputFormatters: [_UpperCaseTextFormatter()],
                    decoration: const InputDecoration(labelText: 'รหัสย่อ'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, LaooTypography.buttonHeight),
                    alignment: Alignment.center,
                  ),
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('ยกเลิก'),
                ),
                if (widget.canSave)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(100, LaooTypography.buttonHeight),
                      alignment: Alignment.center,
                    ),
                    onPressed: _saving ? null : _sync,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
