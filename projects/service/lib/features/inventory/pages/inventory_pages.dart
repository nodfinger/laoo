import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/inventory_api.dart';

String _inventoryError(String action, Object error) =>
    'ไม่สามารถ$actionได้\nรายละเอียดเพิ่มเติม: ${error.toString()}';

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});
  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  final _api = InventoryApi(),
      _search = TextEditingController(),
      _code = TextEditingController(),
      _name = TextEditingController();
  final _profile = UserProfileRepository();
  List<Map<String, dynamic>> _rows = const [], _branches = const [];
  Map<String, bool> _actions = const {};
  int? _editingId, _branchId, _filterBranchId;
  bool _loading = true,
      _active = true,
      _default = false,
      _saving = false,
      _card = false;
  static const _pageSize = 10;
  int _page = 0;
  String _menuName = 'คลังสินค้า';
  String? _branchError, _codeError, _nameError;

  @override
  void initState() {
    super.initState();
    _resolveMenuName();
    _loadViewMode();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _resolveMenuName() async {
    try {
      final value = await NavigationMenuRepository().resolveMenuName(
        menuCode: '08004',
        routeName: 'warehouses',
        fallback: _menuName,
      );
      if (mounted && value.trim().isNotEmpty) {
        setState(() => _menuName = value.trim());
      }
    } catch (_) {}
  }

  Future<void> _loadViewMode() async {
    try {
      final profile = await _profile.get();
      if (mounted) {
        setState(
          () => _card = '${profile['defaultViewMode']}'.toUpperCase() == 'CARD',
        );
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _api.warehouses(search: _search.text),
        _api.branches(),
        _api.actions('warehouses'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = values[0] as List<Map<String, dynamic>>;
        _branches = values[1] as List<Map<String, dynamic>>;
        _actions = values[2] as Map<String, bool>;
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดรายการคลัง', e),
          error: true,
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRows => _filterBranchId == null
      ? _rows
      : _rows
            .where(
              (row) => (row['branchID'] as num?)?.toInt() == _filterBranchId,
            )
            .toList();

  void _new() {
    setState(() {
      _editingId = null;
      _code.clear();
      _name.clear();
      _branchId = _branches.isEmpty
          ? null
          : (_branches.first['branchID'] as num).toInt();
      _active = true;
      _default = false;
      _saving = false;
      _branchError = _codeError = _nameError = null;
    });
    _openWarehouseDialog();
  }

  void _edit(Map<String, dynamic> row) {
    setState(() {
      _editingId = (row['warehouseID'] as num).toInt();
      _code.text = '${row['warehouseCode']}';
      _name.text = '${row['warehouseName']}';
      _branchId = (row['branchID'] as num).toInt();
      _active = row['isActive'] == true;
      _default = row['isDefault'] == true;
      _saving = false;
      _branchError = _codeError = _nameError = null;
    });
    _openWarehouseDialog();
  }

  Future<void> _save(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    if (_saving) return;
    setDialogState(() {
      _branchError = _branchId == null ? 'กรุณาเลือกสาขา' : null;
      _codeError = _code.text.trim().isEmpty ? 'กรุณาระบุรหัสคลัง' : null;
      _nameError = _name.text.trim().isEmpty ? 'กรุณาระบุชื่อคลัง' : null;
    });
    if (_branchError != null || _codeError != null || _nameError != null) {
      return;
    }
    final wasNew = _editingId == null;
    setDialogState(() => _saving = true);
    try {
      await _api.saveWarehouse({
        'branchID': _branchId,
        'warehouseCode': _code.text.trim(),
        'warehouseName': _name.text.trim(),
        'isDefault': _default,
        'isActive': _active,
      }, id: _editingId);
      if (!mounted) return;
      showTimedSnackBar(context, message: 'บันทึกคลังแล้ว');
      await _load();
      if (!mounted) return;
      if (!wasNew) {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        return;
      }
      setDialogState(() {
        if (wasNew) {
          for (final row in _rows) {
            if ('${row['warehouseCode']}' == _code.text.trim() &&
                (row['branchID'] as num?)?.toInt() == _branchId) {
              _editingId = (row['warehouseID'] as num).toInt();
              break;
            }
          }
        }
        _saving = false;
      });
    } catch (e) {
      if (mounted) {
        setDialogState(() => _saving = false);
        showTimedSnackBar(
          context,
          message: _inventoryError('บันทึกคลัง', e),
          error: true,
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final name = '${row['warehouseCode']} | ${row['warehouseName']}';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: LaooColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: const Row(
              children: [
                Icon(Icons.delete_outline, color: LaooColors.error),
                SizedBox(width: 8),
                Text(
                  'ยืนยันการลบคลังสินค้า',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(color: LaooColors.border),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFFFEBEE),
                  child: Text(name),
                ),
                const SizedBox(height: 10),
                const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LaooColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
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
    try {
      await _api.deleteWarehouse((row['warehouseID'] as num).toInt());
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ปิดคลังสินค้าแล้ว');
      await _load();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError('ปิดคลังสินค้า', e),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _menuName,
    activeMenu: 'warehouses',
    menuScope: WorkspaceMenuScope.company,
    child: ColoredBox(
      color: LaooColors.background,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: _list(),
      ),
    ),
  );
  Widget _list() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      final cardMode = compact || _card;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _listHeader(context, compact: compact, cardMode: cardMode),
          const SizedBox(height: 6),
          _filterCard(context),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(child: _resultCard(context, cardMode: cardMode)),
          const SizedBox(height: LaooLayout.cardSpacing),
          _paginationCard(context),
        ],
      );
    },
  );

  Widget _listHeader(
    BuildContext context, {
    required bool compact,
    required bool cardMode,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.star_border_rounded, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _menuName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!compact)
                  OutlinedButton(
                    onPressed: () => setState(() => _card = !cardMode),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 40),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    child: Icon(
                      cardMode
                          ? Icons.list_alt_outlined
                          : Icons.grid_view_rounded,
                    ),
                  ),
                if (!compact) const SizedBox(width: 8),
                if (_actions['create'] == true)
                  FilledButton.icon(
                    onPressed: _new,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มคลัง'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget searchField(double width) => SizedBox(
      width: width,
      child: TextField(
        controller: _search,
        style: const TextStyle(fontSize: LaooTypography.inputText),
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          hintText: 'ค้นหารหัสหรือชื่อคลัง',
          hintStyle: const TextStyle(fontSize: LaooTypography.inputText),
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: _filterBorder(LaooColors.border),
          enabledBorder: _filterBorder(LaooColors.border),
          focusedBorder: _filterBorder(primary, width: 1.5),
        ),
      ),
    );
    final branchFilter = SizedBox(
      width: 280,
      child: DropdownButtonFormField<int?>(
        key: ValueKey(_filterBranchId),
        initialValue: _filterBranchId,
        isExpanded: true,
        style: const TextStyle(
          color: LaooColors.textPrimary,
          fontSize: LaooTypography.comboBox,
        ),
        decoration: InputDecoration(
          labelText: 'สาขา',
          isDense: true,
          border: _filterBorder(LaooColors.border),
          enabledBorder: _filterBorder(LaooColors.border),
          focusedBorder: _filterBorder(primary, width: 1.5),
        ),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('ทุกสาขา')),
          ..._branches.map(
            (branch) => DropdownMenuItem<int?>(
              value: (branch['branchID'] as num).toInt(),
              child: Text('${branch['branchCode']} | ${branch['branchName']}'),
            ),
          ),
        ],
        onChanged: (value) => setState(() {
          _filterBranchId = value;
          _page = 0;
        }),
      ),
    );
    final searchAction = FilledButton.icon(
      onPressed: _load,
      style: _filterButtonStyle(),
      icon: const Icon(Icons.search, size: 18),
      label: const Text('ค้นหา'),
    );
    final clearAction = OutlinedButton.icon(
      onPressed: () {
        _search.clear();
        setState(() => _filterBranchId = null);
        _load();
      },
      style: _filterButtonStyle(),
      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
      label: const Text('ล้าง Filter'),
    );

    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [searchAction, const SizedBox(width: 8), clearAction],
            );
            final searchGroup = Row(
              mainAxisSize: MainAxisSize.min,
              children: [searchField(260), const SizedBox(width: 8), actions],
            );
            if (constraints.maxWidth >= 800) {
              return Row(
                children: [branchFilter, const SizedBox(width: 8), searchGroup],
              );
            }
            if (constraints.maxWidth >= 510) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [branchFilter, searchGroup],
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: constraints.maxWidth, child: branchFilter),
                searchField(constraints.maxWidth.clamp(0, 260).toDouble()),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  OutlineInputBorder _filterBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: BorderSide(color: color, width: width),
      );

  ButtonStyle _filterButtonStyle() => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14, vertical: 0),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: LaooTypography.button, fontWeight: FontWeight.w700),
    ),
  );

  Widget _resultCard(BuildContext context, {required bool cardMode}) {
    final primary = Theme.of(context).colorScheme.primary;
    final filteredRows = _filteredRows;
    final start = _page * _pageSize;
    final pageRows = filteredRows.skip(start).take(_pageSize).toList();
    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : filteredRows.isEmpty
          ? const Center(child: Text('ไม่พบข้อมูลคลังสินค้า'))
          : cardMode
          ? ListView.separated(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              itemCount: pageRows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) =>
                  _warehouseCard(context, pageRows[index], primary),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth < 900
                      ? 900
                      : constraints.maxWidth,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      primary.withValues(alpha: .10),
                    ),
                    headingTextStyle: TextStyle(
                      color: primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    dataTextStyle: const TextStyle(
                      color: LaooColors.textPrimary,
                      fontSize: 13,
                    ),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(
                        label: SizedBox(
                          width: 132,
                          child: Center(child: Text('Action')),
                        ),
                      ),
                      DataColumn(label: Text('สาขา')),
                      DataColumn(label: Text('รหัสคลัง')),
                      DataColumn(label: Text('ชื่อคลัง')),
                      DataColumn(label: Text('คลังหลัก')),
                      DataColumn(label: Text('สถานะ')),
                    ],
                    rows: pageRows
                        .asMap()
                        .entries
                        .map(
                          (entry) => _warehouseDataRow(
                            entry.value,
                            primary,
                            displayId: start + entry.key + 1,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
    );
  }

  DataRow _warehouseDataRow(
    Map<String, dynamic> row,
    Color primary, {
    required int displayId,
  }) => DataRow(
    cells: [
      DataCell(Text('$displayId')),
      DataCell(
        SizedBox(width: 132, child: Center(child: _rowActions(row, primary))),
      ),
      DataCell(Text('${row['branchName']}')),
      DataCell(Text('${row['warehouseCode']}')),
      DataCell(Text('${row['warehouseName']}')),
      DataCell(
        Icon(
          row['isDefault'] == true
              ? Icons.check_circle_outline
              : Icons.remove_circle_outline,
          color: row['isDefault'] == true ? primary : LaooColors.textSecondary,
        ),
      ),
      DataCell(_status(row, primary)),
    ],
  );

  Widget _paginationCard(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final total = _filteredRows.length;
    final pageCount = math.max(1, (total / _pageSize).ceil()).toInt();
    final currentPage = _page.clamp(0, pageCount - 1).toInt();
    final start = total == 0 ? 0 : (currentPage * _pageSize) + 1;
    final end = total == 0 ? 0 : math.min((currentPage + 1) * _pageSize, total);
    final canPrevious = currentPage > 0;
    final canNext = currentPage < pageCount - 1;

    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: SizedBox(
        height: LaooLayout.paginationCardHeight,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LaooLayout.cardPadding,
                ),
                child: Row(
                  children: [
                    _paginationButton(
                      label: '<',
                      primary: primary,
                      enabled: canPrevious,
                      onPressed: () => setState(() => _page = currentPage - 1),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: FilledButton(
                        onPressed: null,
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: primary,
                          disabledForegroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        child: Text('${currentPage + 1}'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _paginationButton(
                      label: '>',
                      primary: primary,
                      enabled: canNext,
                      onPressed: () => setState(() => _page = currentPage + 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$start-$end จาก $total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: LaooTypography.button),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginationButton({
    required String label,
    required Color primary,
    required bool enabled,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: 36,
    height: 36,
    child: OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: LaooColors.textSecondary,
        side: BorderSide(color: enabled ? primary : LaooColors.textSecondary),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      ),
      child: Text(label),
    ),
  );

  Widget _warehouseCard(
    BuildContext context,
    Map<String, dynamic> row,
    Color primary,
  ) => Card(
    margin: EdgeInsets.zero,
    color: LaooColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warehouse_outlined, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${row['warehouseCode']} | ${row['warehouseName']}',
                  style: const TextStyle(
                    color: LaooColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _rowActions(row, primary),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: LaooColors.border),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('สาขา: ${row['branchName']}'),
              Text('คลังหลัก: ${row['isDefault'] == true ? 'ใช่' : 'ไม่ใช่'}'),
              _status(row, primary),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _rowActions(Map<String, dynamic> row, Color primary) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: primary,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _edit(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (_actions['edit'] == true)
        IconButton(
          tooltip: 'กำหนดผู้มีสิทธิ์',
          color: primary,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _openWarehouseAccess(row),
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
      if (_actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: LaooColors.error,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _delete(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  Future<void> _openWarehouseAccess(Map<String, dynamic> row) async {
    Map<String, dynamic> configuration;
    try {
      configuration = await _api.warehouseAccess(
        (row['warehouseID'] as num).toInt(),
      );
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดสิทธิ์คลัง', error),
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    final users = (configuration['users'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final searchController = TextEditingController();
    var mode = '${configuration['accessModeCode'] ?? 'INHERIT'}';
    var selected = users
        .where((user) => user['isSelected'] == true)
        .map((user) => (user['userId'] as num).toInt())
        .toSet();
    var query = '';
    var saving = false;
    String? popupMessage;
    var popupHasError = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final primary = Theme.of(dialogContext).colorScheme.primary;
          final visibleUsers = users
              .where((user) {
                final term = query.toLowerCase();
                return term.isEmpty ||
                    '${user['displayName']}'.toLowerCase().contains(term) ||
                    '${user['username']}'.toLowerCase().contains(term);
              })
              .toList(growable: false);
          final border = _popupInputBorder(LaooColors.border);
          final buttonStyle = ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
          );
          return Dialog(
            backgroundColor: LaooColors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(LaooLayout.cardMargin),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(LaooLayout.cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.manage_accounts_outlined, color: primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'กำหนดสิทธิ์เข้าถึงคลัง',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: LaooColors.border),
                      const SizedBox(height: 12),
                      Text(
                        '${configuration['warehouseCode']} | ${configuration['warehouseName']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(mode),
                        initialValue: mode,
                        isExpanded: true,
                        style: const TextStyle(
                          color: LaooColors.textPrimary,
                          fontSize: LaooTypography.comboBox,
                        ),
                        decoration: InputDecoration(
                          labelText: 'การเข้าถึง *',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: _popupInputBorder(primary, width: 1.5),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'INHERIT',
                            child: Text('สืบทอดจากสาขา'),
                          ),
                          DropdownMenuItem(
                            value: 'RESTRICTED',
                            child: Text('เฉพาะผู้เลือก'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() {
                                mode = value ?? 'INHERIT';
                                popupMessage = null;
                                popupHasError = false;
                              }),
                      ),
                      if (mode == 'RESTRICTED') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาชื่อหรือ Username',
                            prefixIcon: const Icon(Icons.search),
                            border: border,
                            enabledBorder: border,
                            focusedBorder: _popupInputBorder(
                              primary,
                              width: 1.5,
                            ),
                          ),
                          onChanged: (value) =>
                              setDialogState(() => query = value.trim()),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: visibleUsers.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: Text('ไม่พบผู้ใช้งาน')),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: visibleUsers.length,
                                  itemBuilder: (_, index) {
                                    final user = visibleUsers[index];
                                    final userId = (user['userId'] as num)
                                        .toInt();
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      value: selected.contains(userId),
                                      title: Text(
                                        '${user['displayName']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${user['username']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onChanged: saving
                                          ? null
                                          : (checked) => setDialogState(() {
                                              if (checked == true) {
                                                selected.add(userId);
                                              } else {
                                                selected.remove(userId);
                                              }
                                              popupMessage = null;
                                              popupHasError = false;
                                            }),
                                    );
                                  },
                                ),
                        ),
                      ],
                      if (popupMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          popupMessage!,
                          style: TextStyle(
                            color: popupHasError
                                ? Theme.of(dialogContext).colorScheme.error
                                : primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: LaooColors.border),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: buttonStyle,
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: const Text('ยกเลิก'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: buttonStyle,
                            onPressed: saving
                                ? null
                                : () async {
                                    setDialogState(() => saving = true);
                                    try {
                                      await _api.updateWarehouseAccess(
                                        (row['warehouseID'] as num).toInt(),
                                        accessModeCode: mode,
                                        userIds: mode == 'INHERIT'
                                            ? const []
                                            : selected,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        saving = false;
                                        popupMessage = 'บันทึกสิทธิ์คลังแล้ว';
                                        popupHasError = false;
                                      });
                                    } catch (error) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        saving = false;
                                        popupMessage = _inventoryError(
                                          'บันทึกสิทธิ์คลัง',
                                          error,
                                        );
                                        popupHasError = true;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('บันทึก'),
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
    );
    searchController.dispose();
  }

  Widget _status(Map<String, dynamic> row, Color primary) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: (row['isActive'] == true ? primary : LaooColors.textSecondary)
          .withValues(alpha: .10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      row['isActive'] == true ? 'ใช้งาน' : 'ปิด',
      style: TextStyle(
        color: row['isActive'] == true ? primary : LaooColors.textSecondary,
        fontSize: 13,
      ),
    ),
  );

  Future<void> _openWarehouseDialog() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => Dialog(
        backgroundColor: LaooColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(LaooLayout.cardMargin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: _warehousePopup(dialogContext, setDialogState),
          ),
        ),
      ),
    ),
  );

  Widget _warehousePopup(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) {
    final primary = Theme.of(dialogContext).colorScheme.primary;
    final actionButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.warehouse_outlined, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_menuName > ${_editingId == null ? 'เพิ่ม' : 'แก้ไข'}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: LaooColors.border),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _switchField(
              'สถานะใช้งาน',
              _active,
              (value) => setDialogState(() => _active = value),
            ),
            _switchField(
              'คลังหลัก',
              _default,
              (value) => setDialogState(() => _default = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(_branchId),
          initialValue: _branchId,
          isExpanded: true,
          style: const TextStyle(
            color: LaooColors.textPrimary,
            fontSize: LaooTypography.comboBox,
          ),
          decoration: _popupInputDecoration(
            dialogContext,
            labelText: 'สาขา *',
            errorText: _branchError,
          ),
          items: _branches
              .map(
                (x) => DropdownMenuItem(
                  value: (x['branchID'] as num).toInt(),
                  child: Text('${x['branchCode']} | ${x['branchName']}'),
                ),
              )
              .toList(),
          onChanged: (value) => setDialogState(() {
            _branchId = value;
            _branchError = null;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          style: const TextStyle(fontSize: LaooTypography.inputText),
          decoration: _popupInputDecoration(
            dialogContext,
            labelText: 'รหัสคลัง *',
            errorText: _codeError,
          ),
          onChanged: (_) {
            if (_codeError != null) {
              setDialogState(() => _codeError = null);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          style: const TextStyle(fontSize: LaooTypography.inputText),
          decoration: _popupInputDecoration(
            dialogContext,
            labelText: 'ชื่อคลัง *',
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) {
              setDialogState(() => _nameError = null);
            }
          },
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: LaooColors.border),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              style: actionButtonStyle,
              child: const Text('ยกเลิก'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () => _save(dialogContext, setDialogState),
              style: actionButtonStyle,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _popupInputDecoration(
    BuildContext context, {
    required String labelText,
    String? errorText,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return InputDecoration(
      labelText: labelText,
      errorText: errorText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: _popupInputBorder(LaooColors.border),
      enabledBorder: _popupInputBorder(LaooColors.border),
      focusedBorder: _popupInputBorder(primary, width: 1.5),
      errorBorder: _popupInputBorder(LaooColors.error),
      focusedErrorBorder: _popupInputBorder(LaooColors.error, width: 1.5),
    );
  }

  OutlineInputBorder _popupInputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _switchField(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: LaooColors.textPrimary)),
          const SizedBox(width: 6),
          Switch(value: value, onChanged: onChanged),
        ],
      );
}

class SerialRegistryPage extends StatefulWidget {
  const SerialRegistryPage({super.key});
  @override
  State<SerialRegistryPage> createState() => _SerialRegistryPageState();
}

class _SerialRegistryPageState extends State<SerialRegistryPage> {
  final _api = InventoryApi(), _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [],
      _history = const [],
      _warranties = const [];
  bool _loading = true;
  String? _usageFilter, _projectFilter;
  Map<String, dynamic>? _selected;

  List<Map<String, dynamic>> get _visibleRows => _rows
      .where((row) {
        final usages = '${row['usageCodes'] ?? ''}'.split(',');
        final projects = '${row['projectCodes'] ?? ''}'.split(',');
        return (_usageFilter == null || usages.contains(_usageFilter)) &&
            (_projectFilter == null || projects.contains(_projectFilter));
      })
      .toList(growable: false);

  List<Map<String, String>> _codeOptions(String field) {
    final values = <String>{};
    for (final row in _rows) {
      values.addAll(
        '${row[field] ?? ''}'.split(',').where((value) => value.isNotEmpty),
      );
    }
    return values
        .map(
          (value) => {
            'value': value,
            'label': value == 'ALL' ? 'ทุก Project' : value,
          },
        )
        .toList()
      ..sort((a, b) => a['label']!.compareTo(b['label']!));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _api.instances(search: _search.text);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดทะเบียน Serial', e),
          error: true,
        );
      }
    }
  }

  Future<void> _select(Map<String, dynamic> row) async {
    try {
      final id = (row['itemInstanceID'] as num).toInt();
      final values = await Future.wait([
        _api.instanceHistory(id),
        _api.instanceWarranties(id),
      ]);
      if (mounted) {
        setState(() {
          _selected = row;
          _history = values[0];
          _warranties = values[1];
        });
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดประวัติ Serial', e),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'ทะเบียน Serial/อุปกรณ์',
    activeMenu: 'itemInstances',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SerialRegistryToolbar(
            controller: _search,
            count: _visibleRows.length,
            usageFilter: _usageFilter,
            projectFilter: _projectFilter,
            usageOptions: _codeOptions('usageCodes'),
            projectOptions: _codeOptions('projectCodes'),
            onFilterChanged: (usage, project) => setState(() {
              _usageFilter = usage;
              _projectFilter = project;
              _selected = null;
            }),
            onSearch: _load,
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(900, constraints.maxWidth),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: LaooColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : LayoutBuilder(
                                  builder: (context, constraints) => SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: math.max(
                                        720,
                                        constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        headingRowColor: WidgetStatePropertyAll(
                                          Theme.of(context).colorScheme.primary
                                              .withValues(alpha: .10),
                                        ),
                                        headingTextStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        dataTextStyle: const TextStyle(
                                          color: LaooColors.textPrimary,
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        dividerThickness: .5,
                                        dataRowMinHeight: 56,
                                        dataRowMaxHeight: 64,
                                        columns: const [
                                          DataColumn(label: Text('Serial')),
                                          DataColumn(label: Text('Item')),
                                          DataColumn(label: Text('สถานะ')),
                                          DataColumn(label: Text('คลัง')),
                                        ],
                                        rows: _visibleRows
                                            .map(
                                              (x) => DataRow(
                                                selected: identical(
                                                  x,
                                                  _selected,
                                                ),
                                                onSelectChanged: (_) =>
                                                    _select(x),
                                                cells: [
                                                  DataCell(
                                                    Text('${x['serialNo']}'),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      '${x['itemCode']} | ${x['itemName']}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _SerialRegistryStatus(
                                                      code:
                                                          '${x['statusCode']}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      '${x['warehouseCode'] ?? '-'}',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: LaooLayout.cardSpacing),
                      Expanded(
                        flex: 2,
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: LaooColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              LaooLayout.cardPadding,
                            ),
                            child: _selected == null
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.touch_app_outlined,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'เลือกรายการ Serial เพื่อดูรายละเอียด',
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: .10),
                                          borderRadius: BorderRadius.circular(
                                            LaooRadius.xs,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_selected!['serialNo']}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_selected!['itemCode']} | ${_selected!['itemName']}',
                                            ),
                                            const SizedBox(height: 8),
                                            _SerialRegistryStatus(
                                              code:
                                                  '${_selected!['statusCode']}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.verified_outlined,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'ประกัน',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (_warranties.isEmpty)
                                        const Text('ยังไม่มีข้อมูลประกัน')
                                      else
                                        ..._warranties.map(
                                          (x) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: LaooColors.border,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    LaooRadius.xs,
                                                  ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${x['coverageTypeCode'] == 'SUPPLIER' ? 'ประกันผู้ขาย' : 'ประกันลูกค้า'} · ${x['warrantyModeCode'] == 'LIFETIME'
                                                      ? 'ตลอดอายุ'
                                                      : x['warrantyModeCode'] == 'NONE'
                                                      ? 'ไม่มีประกัน'
                                                      : '${x['durationMonths']} เดือน'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'เริ่ม ${_serialRegistryDate(x['startDate'])}${x['expireDate'] == null ? ' · ตลอดอายุ' : ' · หมด ${_serialRegistryDate(x['expireDate'])}'}',
                                                ),
                                                Text(
                                                  'จาก ${x['startEventCode'] ?? '-'}',
                                                  style: const TextStyle(
                                                    color: LaooColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.history_outlined,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'ประวัติ Serial',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ..._history.map(
                                        (x) => Container(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: LaooColors.border,
                                                width: .5,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            '${x['fromStatusCode'] ?? '-'} → ${x['toStatusCode']}\n${x['documentType']} · ${_serialRegistryDate(x['eventDate'])}${'${x['remark'] ?? ''}'.trim().isEmpty ? '' : '\n${x['remark']}'}',
                                          ),
                                        ),
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
            ),
          ),
        ],
      ),
    ),
  );
}

String _serialRegistryDate(Object? value) {
  final text = '${value ?? ''}';
  if (text.length < 10) return text.isEmpty ? '-' : text;
  final parts = text.substring(0, 10).split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : text;
}

class _SerialRegistryToolbar extends StatelessWidget {
  const _SerialRegistryToolbar({
    required this.controller,
    required this.count,
    required this.usageFilter,
    required this.projectFilter,
    required this.usageOptions,
    required this.projectOptions,
    required this.onFilterChanged,
    required this.onSearch,
  });

  final TextEditingController controller;
  final int count;
  final String? usageFilter, projectFilter;
  final List<Map<String, String>> usageOptions, projectOptions;
  final void Function(String?, String?) onFilterChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    Widget card(Widget child) => Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: child,
      ),
    );

    Widget filter(
      String label,
      String? value,
      List<Map<String, String>> options,
      void Function(String?) onChanged,
    ) => SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value ?? '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
          ...options.map(
            (option) => DropdownMenuItem(
              value: option['value'],
              child: Text(option['label']!),
            ),
          ),
        ],
        onChanged: (next) => onChanged(next?.isEmpty == true ? null : next),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          Row(
            children: [
              Icon(Icons.qr_code_2_outlined, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ทะเบียน SN/อุปกรณ์',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        card(
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth > 620
                      ? 320
                      : constraints.maxWidth,
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => onSearch(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'ค้นหา Serial, รหัส หรือชื่อสินค้า',
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
                filter(
                  'วัตถุประสงค์',
                  usageFilter,
                  usageOptions,
                  (value) => onFilterChanged(value, projectFilter),
                ),
                filter(
                  'Project ที่นำไปใช้',
                  projectFilter,
                  projectOptions,
                  (value) => onFilterChanged(usageFilter, value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SerialRegistryStatus extends StatelessWidget {
  const _SerialRegistryStatus({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const labels = {
      'IN_STOCK': 'อยู่ในคลัง',
      'RESERVED': 'จอง',
      'ISSUED': 'เบิกใช้',
      'SOLD': 'ขายแล้ว',
      'INSTALLED': 'ติดตั้งแล้ว',
      'REPAIR': 'ซ่อม',
      'RETIRED': 'เลิกใช้',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Text(
        labels[code] ?? code,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: LaooTypography.inputText,
        ),
      ),
    );
  }
}

class InventoryItemCatalogPage extends StatefulWidget {
  const InventoryItemCatalogPage({super.key});
  @override
  State<InventoryItemCatalogPage> createState() =>
      _InventoryItemCatalogPageState();
}

class _InventoryItemCatalogPageState extends State<InventoryItemCatalogPage> {
  final _api = InventoryApi();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await _api.issueLookup();
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(
            value['items'] as List? ?? const [],
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดรายการอะไหล่และวัสดุ', e),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'รายการอะไหล่และวัสดุ',
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _Header(title: 'รายการอะไหล่และวัสดุ'),
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : DataTable(
                  columns: const [
                    DataColumn(label: Text('รหัส')),
                    DataColumn(label: Text('ชื่อ')),
                    DataColumn(label: Text('วิธีควบคุมสต็อก')),
                  ],
                  rows: _items
                      .map(
                        (x) => DataRow(
                          cells: [
                            DataCell(Text('${x['itemCode']}')),
                            DataCell(Text('${x['itemName']}')),
                            DataCell(Text('${x['stockTrackingCode']}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );
}

class InventoryIssuePage extends StatefulWidget {
  const InventoryIssuePage({super.key});
  @override
  State<InventoryIssuePage> createState() => _InventoryIssuePageState();
}

class _InventoryIssuePageState extends State<InventoryIssuePage> {
  final _api = InventoryApi(),
      _workId = TextEditingController(),
      _workCode = TextEditingController(),
      _qty = TextEditingController(text: '1'),
      _serials = TextEditingController();
  List<Map<String, dynamic>> _rows = const [],
      _warehouses = const [],
      _items = const [],
      _availableSerials = const [];
  int? _warehouseId, _itemId;
  bool _loading = true, _editing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _workId.dispose();
    _workCode.dispose();
    _qty.dispose();
    _serials.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([_api.issues(), _api.issueLookup()]);
      final lookup = values[1] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _rows = values[0] as List<Map<String, dynamic>>;
          _warehouses = List<Map<String, dynamic>>.from(
            lookup['warehouses'] as List? ?? const [],
          );
          _items = List<Map<String, dynamic>>.from(
            lookup['items'] as List? ?? const [],
          );
          _availableSerials = List<Map<String, dynamic>>.from(
            lookup['serials'] as List? ?? const [],
          );
          _warehouseId =
              _warehouseId ??
              (_warehouses.isEmpty
                  ? null
                  : (_warehouses.first['warehouseID'] as num).toInt());
          _itemId =
              _itemId ??
              (_items.isEmpty ? null : (_items.first['itemID'] as num).toInt());
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดใบเบิกจ่าย', e),
          error: true,
        );
      }
    }
  }

  Future<void> _save() async {
    final work = int.tryParse(_workId.text), qty = double.tryParse(_qty.text);
    if (work == null ||
        _workCode.text.trim().isEmpty ||
        _warehouseId == null ||
        _itemId == null ||
        qty == null ||
        qty <= 0) {
      showTimedSnackBar(
        context,
        message:
            'ข้อมูลไม่ครบ\nรายละเอียดเพิ่มเติม: กรุณาระบุใบงาน คลัง สินค้า และจำนวน',
        error: true,
      );
      return;
    }
    final serialIds = _serials.text
        .split(',')
        .map((x) => int.tryParse(x.trim()))
        .whereType<int>()
        .toList();
    try {
      await _api.createIssue({
        'warehouseID': _warehouseId,
        'workOrderID': work,
        'workOrderCode': _workCode.text.trim(),
        'items': [
          {
            'itemID': _itemId,
            'quantity': qty,
            'serials': serialIds.map((x) => {'itemInstanceID': x}).toList(),
          },
        ],
      });
      if (!mounted) return;
      setState(() => _editing = false);
      showTimedSnackBar(context, message: 'บันทึกใบเบิกจ่ายแล้ว');
      await _load();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError('บันทึกใบเบิกจ่าย', e),
          error: true,
        );
      }
    }
  }

  Future<void> _change(int id, bool confirm) async {
    try {
      if (confirm) {
        await _api.confirmIssue(id);
      } else {
        await _api.voidIssue(id);
      }
      if (mounted) {
        showTimedSnackBar(
          context,
          message: confirm ? 'ยืนยันใบเบิกจ่ายแล้ว' : 'ยกเลิกและคืนสต็อกแล้ว',
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError(
            confirm ? 'ยืนยันใบเบิกจ่าย' : 'ยกเลิกใบเบิกจ่าย',
            e,
          ),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'เบิก-จ่ายอะไหล่ตามใบงาน',
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(
          title: 'เบิก-จ่ายอะไหล่ตามใบงาน',
          onAdd: _editing ? null : () => setState(() => _editing = true),
          onBack: _editing ? () => setState(() => _editing = false) : null,
          onSave: _editing ? _save : null,
        ),
        const SizedBox(height: 6),
        if (_editing)
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _workId,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Work Order ID *',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _workCode,
                      decoration: const InputDecoration(
                        labelText: 'รหัสใบงาน *',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<int>(
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(labelText: 'คลัง *'),
                      items: _warehouses
                          .map(
                            (x) => DropdownMenuItem(
                              value: (x['warehouseID'] as num).toInt(),
                              child: Text(
                                '${x['warehouseCode']} | ${x['warehouseName']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _warehouseId = v),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<int>(
                      initialValue: _itemId,
                      decoration: const InputDecoration(
                        labelText: 'อะไหล่/วัสดุ *',
                      ),
                      items: _items
                          .map(
                            (x) => DropdownMenuItem(
                              value: (x['itemID'] as num).toInt(),
                              child: Text(
                                '${x['itemCode']} | ${x['itemName']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _itemId = v),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'จำนวน *'),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _serials,
                      decoration: InputDecoration(
                        labelText: 'Serial IDs (คั่นด้วย ,)',
                        helperText:
                            'พร้อมใช้ ${_availableSerials.where((x) => x['itemID'] == _itemId && x['warehouseID'] == _warehouseId).length} รายการ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('เลขที่')),
                      DataColumn(label: Text('วันที่')),
                      DataColumn(label: Text('ใบงาน')),
                      DataColumn(label: Text('สถานะ')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: _rows.map((x) {
                      final id = (x['stockIssueID'] as num).toInt(),
                          status = '${x['statusCode']}';
                      return DataRow(
                        cells: [
                          DataCell(Text('${x['issueCode']}')),
                          DataCell(Text('${x['issueDate']}'.split('T').first)),
                          DataCell(Text('${x['workOrderCode']}')),
                          DataCell(Text(status)),
                          DataCell(
                            Row(
                              children: [
                                if (status == 'DRAFT')
                                  TextButton(
                                    onPressed: () => _change(id, true),
                                    child: const Text('ยืนยัน'),
                                  ),
                                if (status == 'CONFIRMED')
                                  TextButton(
                                    onPressed: () => _change(id, false),
                                    child: const Text('ยกเลิก'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onAdd, this.onBack, this.onSave});
  final String title;
  final VoidCallback? onAdd, onBack, onSave;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          const Icon(Icons.star_border, color: Colors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onAdd != null)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่ม'),
            ),
          if (onSave != null)
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
        ],
      ),
    ),
  );
}
