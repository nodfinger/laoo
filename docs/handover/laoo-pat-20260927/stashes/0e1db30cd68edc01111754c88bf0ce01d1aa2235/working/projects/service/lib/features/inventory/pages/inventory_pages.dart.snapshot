import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
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
  int? _editingId, _branchId;
  bool _loading = true,
      _active = true,
      _default = false,
      _editing = false,
      _card = false;
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

  void _new() {
    setState(() {
      _editing = true;
      _editingId = null;
      _code.clear();
      _name.clear();
      _branchId = _branches.isEmpty
          ? null
          : (_branches.first['branchID'] as num).toInt();
      _active = true;
      _default = false;
      _branchError = _codeError = _nameError = null;
    });
  }

  void _edit(Map<String, dynamic> row) {
    setState(() {
      _editing = true;
      _editingId = (row['warehouseID'] as num).toInt();
      _code.text = '${row['warehouseCode']}';
      _name.text = '${row['warehouseName']}';
      _branchId = (row['branchID'] as num).toInt();
      _active = row['isActive'] == true;
      _default = row['isDefault'] == true;
      _branchError = _codeError = _nameError = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _branchError = _branchId == null ? 'กรุณาเลือกสาขา' : null;
      _codeError = _code.text.trim().isEmpty ? 'กรุณาระบุรหัสคลัง' : null;
      _nameError = _name.text.trim().isEmpty ? 'กรุณาระบุชื่อคลัง' : null;
    });
    if (_branchError != null || _codeError != null || _nameError != null) {
      return;
    }
    try {
      await _api.saveWarehouse({
        'branchID': _branchId,
        'warehouseCode': _code.text.trim(),
        'warehouseName': _name.text.trim(),
        'isDefault': _default,
        'isActive': _active,
      }, id: _editingId);
      if (!mounted) return;
      setState(() => _editing = false);
      showTimedSnackBar(context, message: 'บันทึกคลังแล้ว');
      await _load();
    } catch (e) {
      if (mounted) {
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
        child: _editing ? _form() : _list(),
      ),
    ),
  );
  Widget _list() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      final cardMode = compact || _card;
      return Column(
        children: [
          _listHeader(context, compact: compact, cardMode: cardMode),
          const SizedBox(height: 6),
          _filterCard(context),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(child: _resultCard(context, cardMode: cardMode)),
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
            const SizedBox(height: 8),
            const Divider(height: 1, color: LaooColors.border),
          ],
        ),
      ),
    );
  }

  Widget _filterCard(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: LaooColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.arrow_forward),
                labelText: 'ค้นหารหัสหรือชื่อคลัง',
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              _search.clear();
              _load();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
        ],
      ),
    ),
  );

  Widget _resultCard(BuildContext context, {required bool cardMode}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _rows.isEmpty
          ? const Center(child: Text('ไม่พบข้อมูลคลังสินค้า'))
          : cardMode
          ? ListView.separated(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) =>
                  _warehouseCard(context, _rows[index], primary),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('สาขา')),
                  DataColumn(label: Text('รหัสคลัง')),
                  DataColumn(label: Text('ชื่อคลัง')),
                  DataColumn(label: Text('คลังหลัก')),
                  DataColumn(label: Text('สถานะ')),
                ],
                rows: _rows
                    .map((row) => _warehouseDataRow(row, primary))
                    .toList(),
              ),
            ),
    );
  }

  DataRow _warehouseDataRow(Map<String, dynamic> row, Color primary) => DataRow(
    cells: [
      DataCell(Text('${row['warehouseID']}')),
      DataCell(_rowActions(row, primary)),
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
          onPressed: () => _edit(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (_actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: LaooColors.error,
          onPressed: () => _delete(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

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

  Widget _form() => ListView(
    children: [
      _formHeader(),
      const SizedBox(height: LaooLayout.cardSpacing),
      Card(
        margin: EdgeInsets.zero,
        color: LaooColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _switchField(
                    'สถานะใช้งาน',
                    _active,
                    (v) => setState(() => _active = v),
                  ),
                  _switchField(
                    'คลังหลัก',
                    _default,
                    (v) => setState(() => _default = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth >= 760
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth,
                      child: DropdownButtonFormField<int>(
                        initialValue: _branchId,
                        decoration: InputDecoration(
                          labelText: 'สาขา *',
                          errorText: _branchError,
                        ),
                        items: _branches
                            .map(
                              (x) => DropdownMenuItem(
                                value: (x['branchID'] as num).toInt(),
                                child: Text(
                                  '${x['branchCode']} | ${x['branchName']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _branchId = v;
                          _branchError = null;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth >= 760
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth,
                      child: TextField(
                        controller: _code,
                        decoration: InputDecoration(
                          labelText: 'รหัสคลัง *',
                          errorText: _codeError,
                        ),
                        onChanged: (_) {
                          if (_codeError != null) {
                            setState(() => _codeError = null);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: 'ชื่อคลัง *',
                          errorText: _nameError,
                        ),
                        onChanged: (_) {
                          if (_nameError != null) {
                            setState(() => _nameError = null);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _formHeader() => Card(
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
              Icon(
                Icons.star_border_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
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
              OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('ยกเลิก'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('บันทึก'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: LaooColors.border),
        ],
      ),
    ),
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

class StockReceiptPage extends StatefulWidget {
  const StockReceiptPage({super.key});
  @override
  State<StockReceiptPage> createState() => _StockReceiptPageState();
}

class _StockReceiptPageState extends State<StockReceiptPage> {
  final _api = InventoryApi(),
      _search = TextEditingController(),
      _reference = TextEditingController(),
      _remark = TextEditingController();
  List<Map<String, dynamic>> _rows = const [],
      _warehouses = const [],
      _items = const [];
  Map<String, bool> _actions = const {};
  List<_ReceiptLine> _lines = [];
  bool _loading = true, _editing = false;
  int? _editingId, _warehouseId;
  String _receiptType = 'RECEIPT';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    _reference.dispose();
    _remark.dispose();
    for (final x in _lines) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _api.receipts(search: _search.text),
        _api.receiptLookup(),
        _api.actions('stock-receipts'),
      ]);
      if (!mounted) return;
      final lookup = values[1] as Map<String, dynamic>;
      setState(() {
        _rows = values[0] as List<Map<String, dynamic>>;
        _warehouses = List<Map<String, dynamic>>.from(
          lookup['warehouses'] ?? [],
        );
        _items = List<Map<String, dynamic>>.from(lookup['items'] ?? []);
        _actions = values[2] as Map<String, bool>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _inventoryError('โหลดใบรับสินค้า', e),
          error: true,
        );
      }
    }
  }

  void _new() {
    for (final x in _lines) {
      x.dispose();
    }
    setState(() {
      _editing = true;
      _editingId = null;
      _warehouseId = _warehouses.isEmpty
          ? null
          : (_warehouses.first['warehouseID'] as num).toInt();
      _receiptType = 'RECEIPT';
      _reference.clear();
      _remark.clear();
      _lines = [];
    });
  }

  void _addLine() {
    if (_items.isEmpty) return;
    setState(() => _lines.add(_ReceiptLine(item: _items.first)));
  }

  Future<void> _save() async {
    if (_warehouseId == null || _lines.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ข้อมูลรับสินค้าไม่ครบ\nรายละเอียดเพิ่มเติม: กรุณาเลือกคลังและเพิ่มรายการ',
        error: true,
      );
      return;
    }
    try {
      await _api.saveReceipt({
        'warehouseID': _warehouseId,
        'receiptDate': DateTime.now().toIso8601String().substring(0, 10),
        'receiptType': _receiptType,
        'referenceNo': _reference.text.trim(),
        'remark': _remark.text.trim(),
        'items': _lines.map((x) => x.body).toList(),
      }, id: _editingId);
      if (!mounted) return;
      setState(() => _editing = false);
      showTimedSnackBar(context, message: 'บันทึกใบรับสินค้าแล้ว');
      await _load();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError('บันทึกใบรับสินค้า', e),
          error: true,
        );
      }
    }
  }

  Future<void> _confirm(Map<String, dynamic> row) async {
    try {
      await _api.confirmReceipt((row['stockReceiptID'] as num).toInt());
      if (mounted) {
        showTimedSnackBar(context, message: 'ยืนยันรับสินค้าแล้ว');
        await _load();
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _inventoryError('ยืนยันรับสินค้า', e),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'รับสินค้าเข้าคลังและยอดยกมา',
    activeMenu: 'stockReceipts',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: _editing ? _form() : _list(),
    ),
  );
  Widget _list() => Column(
    children: [
      _Header(
        title: 'รับสินค้าเข้าคลังและยอดยกมา',
        onAdd: _actions['create'] == true ? _new : null,
      ),
      const SizedBox(height: 6),
      _Filter(controller: _search, onSearch: _load),
      const SizedBox(height: 6),
      Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('เลขที่')),
                        DataColumn(label: Text('วันที่')),
                        DataColumn(label: Text('คลัง')),
                        DataColumn(label: Text('ประเภท')),
                        DataColumn(label: Text('จำนวน')),
                        DataColumn(label: Text('สถานะ')),
                      ],
                      rows: _rows
                          .map(
                            (row) => DataRow(
                              cells: [
                                DataCell(Text('${row['stockReceiptID']}')),
                                DataCell(
                                  IconButton(
                                    tooltip: 'ยืนยัน',
                                    onPressed:
                                        row['statusCode'] == 'DRAFT' &&
                                            _actions['edit'] == true
                                        ? () => _confirm(row)
                                        : null,
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${row['receiptCode']}')),
                                DataCell(
                                  Text(
                                    '${row['receiptDate']}'.split('T').first,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${row['warehouseCode']} | ${row['warehouseName']}',
                                  ),
                                ),
                                DataCell(Text('${row['receiptType']}')),
                                DataCell(Text('${row['totalQuantity']}')),
                                DataCell(Text('${row['statusCode']}')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
        ),
      ),
    ],
  );
  Widget _form() => ListView(
    children: [
      _Header(
        title: 'รับสินค้าเข้าคลัง > เพิ่ม',
        onBack: () => setState(() => _editing = false),
        onSave: _save,
      ),
      const SizedBox(height: 6),
      Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(labelText: '* คลัง'),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _receiptType,
                      decoration: const InputDecoration(labelText: '* ประเภท'),
                      items: const [
                        DropdownMenuItem(
                          value: 'RECEIPT',
                          child: Text('รับสินค้า'),
                        ),
                        DropdownMenuItem(
                          value: 'OPENING',
                          child: Text('ยอดยกมา'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _receiptType = v ?? 'RECEIPT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'เลขที่อ้างอิง'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remark,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'รายการสินค้า',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มรายการ'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._lines.asMap().entries.map(
                (entry) => _line(entry.key, entry.value),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _line(int index, _ReceiptLine line) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: line.itemId,
                  decoration: const InputDecoration(labelText: '* Item'),
                  items: _items
                      .map(
                        (x) => DropdownMenuItem(
                          value: (x['itemID'] as num).toInt(),
                          child: Text('${x['itemCode']} | ${x['itemName']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final item = _items.firstWhere((x) => x['itemID'] == v);
                    setState(() => line.setItem(item));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: line.quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '* จำนวน'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: line.cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ต้นทุน'),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _lines.removeAt(index));
                  line.dispose();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          if (line.serial) ...[
            const SizedBox(height: 8),
            TextField(
              controller: line.serials,
              decoration: const InputDecoration(
                labelText: '* Serial (หนึ่งรายการต่อหนึ่งบรรทัด)',
              ),
              minLines: 2,
              maxLines: 5,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ReceiptLine {
  _ReceiptLine({required Map<String, dynamic> item}) {
    setItem(item);
  }
  late int itemId;
  bool serial = false;
  final quantity = TextEditingController(text: '1'),
      cost = TextEditingController(text: '0'),
      serials = TextEditingController();
  void setItem(Map<String, dynamic> item) {
    itemId = (item['itemID'] as num).toInt();
    serial = item['stockTrackingCode'] == 'SERIAL';
    if (!serial) serials.clear();
  }

  Map<String, dynamic> get body => {
    'itemID': itemId,
    'quantity': double.tryParse(quantity.text) ?? 0,
    'unitCost': double.tryParse(cost.text) ?? 0,
    'serials': serials.text
        .split(RegExp(r'[\r\n]+'))
        .where((x) => x.trim().isNotEmpty)
        .map((x) => {'serialNo': x.trim()})
        .toList(),
  };
  void dispose() {
    quantity.dispose();
    cost.dispose();
    serials.dispose();
  }
}

class SerialRegistryPage extends StatefulWidget {
  const SerialRegistryPage({super.key});
  @override
  State<SerialRegistryPage> createState() => _SerialRegistryPageState();
}

class _SerialRegistryPageState extends State<SerialRegistryPage> {
  final _api = InventoryApi(), _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [], _history = const [];
  bool _loading = true;
  Map<String, dynamic>? _selected;
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
      final history = await _api.instanceHistory(
        (row['itemInstanceID'] as num).toInt(),
      );
      if (mounted) {
        setState(() {
          _selected = row;
          _history = history;
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
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const _Header(title: 'ทะเบียน Serial/อุปกรณ์'),
          const SizedBox(height: 6),
          _Filter(controller: _search, onSearch: _load),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Serial')),
                                DataColumn(label: Text('Item')),
                                DataColumn(label: Text('สถานะ')),
                                DataColumn(label: Text('คลัง')),
                              ],
                              rows: _rows
                                  .map(
                                    (x) => DataRow(
                                      selected: identical(x, _selected),
                                      onSelectChanged: (_) => _select(x),
                                      cells: [
                                        DataCell(Text('${x['serialNo']}')),
                                        DataCell(
                                          Text(
                                            '${x['itemCode']} | ${x['itemName']}',
                                          ),
                                        ),
                                        DataCell(Text('${x['statusCode']}')),
                                        DataCell(
                                          Text('${x['warehouseCode'] ?? '-'}'),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _selected == null
                          ? const Center(
                              child: Text('เลือกรายการเพื่อดูประวัติ'),
                            )
                          : ListView(
                              children: [
                                Text(
                                  '${_selected!['serialNo']}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                ..._history.map(
                                  (x) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${x['fromStatusCode'] ?? '-'} → ${x['toStatusCode']}',
                                    ),
                                    subtitle: Text(
                                      '${x['documentType']} | ${x['eventDate']}\n${x['remark'] ?? ''}',
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
        ],
      ),
    ),
  );
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

class _Filter extends StatelessWidget {
  const _Filter({required this.controller, required this.onSearch});
  final TextEditingController controller;
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'ค้นหารหัสหรือชื่อ',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
        ],
      ),
    ),
  );
}
