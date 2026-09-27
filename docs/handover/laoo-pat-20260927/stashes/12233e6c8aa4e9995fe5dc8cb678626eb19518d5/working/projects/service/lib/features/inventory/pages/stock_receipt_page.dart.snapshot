import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/company_setup/company_date_formatter.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/inventory_api.dart';

typedef ReceiptVendorCreator =
    Future<Map<String, dynamic>?> Function(BuildContext);

class StockReceiptPage extends StatefulWidget {
  const StockReceiptPage({super.key, this.onCreateVendor});
  final ReceiptVendorCreator? onCreateVendor;
  @override
  State<StockReceiptPage> createState() => _StockReceiptPageState();
}

class _StockReceiptPageState extends State<StockReceiptPage> {
  String _caption = '';
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final caption = await NavigationMenuRepository().resolveMenuName(
        menuCode: '08005',
        routeName: 'stockReceipts',
        fallback: '',
      );
      if (mounted) setState(() => _caption = caption);
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'โหลดชื่อเมนูไม่ได้\nรายละเอียดเพิ่มเติม: กรุณาเปิดหน้าใหม่',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'stockReceipts',
    menuScope: WorkspaceMenuScope.company,
    child: StockReceiptWorkspace(
      caption: _caption,
      onCreateVendor: widget.onCreateVendor,
    ),
  );
}

class StockReceiptWorkspace extends StatefulWidget {
  const StockReceiptWorkspace({
    super.key,
    required this.caption,
    this.api,
    this.onCreateVendor,
  });
  final String caption;
  final InventoryApi? api;
  final ReceiptVendorCreator? onCreateVendor;
  @override
  State<StockReceiptWorkspace> createState() => _StockReceiptWorkspaceState();
}

class _StockReceiptWorkspaceState extends State<StockReceiptWorkspace> {
  late final _api = widget.api ?? InventoryApi();
  final _form = GlobalKey<FormState>();
  final _search = TextEditingController(),
      _reference = TextEditingController(),
      _delivered = TextEditingController(),
      _remark = TextEditingController();
  List<Map<String, dynamic>> _rows = [],
      _items = [],
      _warehouses = [],
      _vendors = [];
  final List<ReceiptDraftLine> _lines = [];
  Map<String, bool> _actions = {};
  bool _loading = true,
      _editing = false,
      _busy = false,
      _createVendor = false,
      _card = false;
  int? _id, _warehouse, _vendor, _listVendor, _listWarehouse;
  int _page = 0;
  static const _pageSize = 10;
  String _type = 'RECEIPT', _code = '', _status = 'DRAFT';
  DateTime _date = DateTime.now();
  Color get _primary => Theme.of(context).colorScheme.primary;
  String get _yearFormat => companySetupController.current?.yearFormat ?? 'C';
  String _displayDate(DateTime value) =>
      CompanyDateFormatter.formatDateByYearFormat(value, _yearFormat);
  String _listDate(Object? value) {
    final text = value?.toString() ?? '';
    final date = DateTime.tryParse(text);
    return date == null ? text : _displayDate(date);
  }

  bool get _usesBuddhistYear {
    switch (_yearFormat.trim().toUpperCase()) {
      case 'B':
      case 'BE':
      case 'T':
      case 'TH':
      case 'THAI':
        return true;
      default:
        return false;
    }
  }

  bool get _editable =>
      _status == 'DRAFT' &&
      (_id == null ? _actions['create'] : _actions['edit']) == true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    for (final c in [_search, _reference, _delivered, _remark]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _error(Object e) => showTimedSnackBar(
    context,
    message: 'ทำรายการรับสินค้าไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $e',
    error: true,
  );
  Future<void> _load() async {
    try {
      final result = await Future.wait([
        _api.receipts(
          search: _search.text,
          vendorId: _listVendor,
          warehouseId: _listWarehouse,
        ),
        _api.receiptLookup(),
        _api.actions('stock-receipts'),
      ]);
      if (!mounted) return;
      final lookup = result[1] as Map<String, dynamic>;
      setState(() {
        _rows = result[0] as List<Map<String, dynamic>>;
        _actions = result[2] as Map<String, bool>;
        _items = List<Map<String, dynamic>>.from(lookup['items'] ?? []);
        _warehouses = List<Map<String, dynamic>>.from(
          lookup['warehouses'] ?? [],
        );
        _vendors = List<Map<String, dynamic>>.from(lookup['vendors'] ?? []);
        _createVendor = lookup['canCreateVendor'] == true;
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _error(e);
      }
    }
  }

  Future<void> _findListVendor() async {
    if (_busy) return;
    final id = await showDialog<int>(
      context: context,
      builder: (_) => ReceiptLookupDialog(
        label: 'ผู้ขาย',
        rows: _vendors,
        prefix: 'vendor',
      ),
    );
    if (id != null && mounted) setState(() => _listVendor = id);
  }

  void _new() {
    if (_busy) return;
    for (final l in _lines) {
      l.dispose();
    }
    setState(() {
      _lines.clear();
      _id = null;
      _code = '';
      _status = 'DRAFT';
      _editing = true;
      _type = 'RECEIPT';
      _vendor = null;
      _date = DateTime.now();
      _warehouse = _warehouses.isEmpty
          ? null
          : (_warehouses.first['warehouseID'] as num).toInt();
      _reference.clear();
      _delivered.clear();
      _remark.clear();
    });
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await _api.receipt((row['stockReceiptID'] as num).toInt());
      if (!mounted) return;
      final h = Map<String, dynamic>.from(data['header']);
      final serials = List<Map<String, dynamic>>.from(data['serials']);
      for (final l in _lines) {
        l.dispose();
      }
      setState(() {
        _id = (h['stockReceiptID'] as num).toInt();
        _warehouse = (h['warehouseID'] as num).toInt();
        _vendor = (h['vendorID'] as num?)?.toInt();
        _code = h['receiptCode'];
        _status = h['statusCode'];
        _type = h['receiptType'];
        _date = DateTime.parse(h['receiptDate']);
        _reference.text = h['referenceNo'] ?? '';
        _delivered.text = h['deliveredBy'] ?? '';
        _remark.text = h['remark'] ?? '';
        _lines.clear();
        for (final raw in data['items'] as List) {
          final item = Map<String, dynamic>.from(raw);
          final matches = _items.where((x) => x['itemID'] == item['itemID']);
          final l =
              ReceiptDraftLine(
                  matches.isEmpty
                      ? item
                      : Map<String, dynamic>.from(matches.first),
                )
                ..quantity.text = '${item['quantity']}'
                ..cost.text = '${item['unitCost']}'
                ..source = item['serialSourceCode'] ?? 'FACTORY'
                ..remark = item['remark'];
          l.selectUnit(
            '${item['unitCode'] ?? l.baseUnit}',
            snapshotFactor: (item['conversionFactor'] as num?)?.toDouble(),
            snapshotBaseUnit: '${item['baseUnitCode'] ?? l.baseUnit}',
          );
          l.setSerials(
            serials
                .where(
                  (s) =>
                      s['stockReceiptDetailID'] == item['stockReceiptDetailID'],
                )
                .map((s) => '${s['serialNo']}')
                .toList(),
            confirmed: true,
          );
          _lines.add(l);
        }
        _editing = true;
      });
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addVendor() async {
    if (_busy || widget.onCreateVendor == null) return;
    setState(() => _busy = true);
    try {
      final vendor = await widget.onCreateVendor!(context);
      final lookup = await _api.receiptLookup();
      if (!mounted) return;
      setState(() {
        _vendors = List<Map<String, dynamic>>.from(lookup['vendors'] ?? []);
        if (vendor != null &&
            _vendors.any((v) => v['vendorID'] == vendor['vendorID'])) {
          _vendor = (vendor['vendorID'] as num).toInt();
        }
      });
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_editable || !_form.currentState!.validate()) return;
    if (_lines.isEmpty) {
      _error('กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ');
      return;
    }
    if (_lines.where((l) => l.serial).fold<double>(0, (n, l) => n + l.baseQty) >
        2000) {
      _error('Serial รวมต้องไม่เกิน 2,000 ชิ้นต่อเอกสาร');
      return;
    }
    final serialLines = _lines.where((l) => l.serial).toList();
    if (serialLines.isNotEmpty) {
      for (final l in serialLines) {
        l.resizeSerials();
      }
      if (_serialLinesAreConfirmedAndValid(serialLines)) {
        await _persist();
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            ReceiptSerialDialog(lines: serialLines, onSave: _persist),
      );
      if (mounted) setState(() {});
    } else {
      await _persist();
    }
  }

  bool _serialLinesAreConfirmedAndValid(List<ReceiptDraftLine> lines) {
    final seen = <String>{};
    for (final line in lines) {
      if (!line.serialConfirmed) return false;
      if (line.source == 'INTERNAL' && line.serialValues.isEmpty) continue;
      if (line.serialValues.length != line.baseQty.toInt()) return false;
      for (final serial in line.serialValues) {
        final value = serial.trim();
        if (value.isEmpty || value.length > 200) return false;
        if (!seen.add(value.toUpperCase())) return false;
      }
    }
    return true;
  }

  Future<bool> _persist() async {
    if (_busy || !_editable) return false;
    setState(() => _busy = true);
    try {
      final saved = await _api.saveReceipt({
        'warehouseID': _warehouse,
        'vendorID': _vendor,
        'receiptType': _type,
        'receiptDate': _date.toIso8601String().substring(0, 10),
        'referenceNo': _reference.text.trim(),
        'deliveredBy': _delivered.text.trim(),
        'remark': _remark.text.trim(),
        'items': _lines.map((l) => l.body).toList(),
      }, id: _id);
      if (!mounted) return true;
      setState(() {
        _id = (saved['stockReceiptID'] as num).toInt();
        _code = saved['receiptCode'];
        _status = 'DRAFT';
        for (final raw in saved['items'] as List) {
          final line = _lines[(raw['lineNo'] as num).toInt() - 1];
          line.setSerials(List<String>.from(raw['serials']), confirmed: true);
        }
      });
      showTimedSnackBar(
        context,
        message: 'บันทึกเอกสารร่างแล้ว ยังไม่เพิ่มยอดสต๊อก',
      );
      return true;
    } catch (e) {
      if (mounted) _error(e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> row) async {
    if (_busy || _actions['edit'] != true) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 480),
        titlePadding: const EdgeInsets.all(LaooLayout.cardPadding),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LaooLayout.cardPadding,
        ),
        actionsPadding: const EdgeInsets.all(LaooLayout.cardPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: _primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ยืนยันรับสินค้าเข้าสต๊อก',
                style: TextStyle(
                  fontSize: LaooTypography.workspaceCaption,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: LaooColors.border),
            Text(
              'เอกสาร ${row['receiptCode']}\nเมื่อยืนยันจะเพิ่มยอดคงเหลือและทะเบียน Serial',
            ),
            const Divider(color: LaooColors.border),
          ],
        ),
        actions: [
          OutlinedButton(
            style: receiptButton(_primary),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: receiptButton(_primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.confirmReceipt((row['stockReceiptID'] as num).toInt());
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ยืนยันรับสินค้าเข้าสต๊อกแล้ว');
      await _load();
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(LaooLayout.cardMargin),
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _editing
        ? _editor()
        : _list(),
  );
  Widget _surface(Widget child, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );
  Widget _title(List<Widget> buttons, {String suffix = '', Key? surfaceKey}) =>
      _surface(
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_border, color: _primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${widget.caption}$suffix',
                    style: const TextStyle(
                      fontSize: LaooTypography.workspaceCaption,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 6, children: buttons),
          ],
        ),
        key: surfaceKey,
      );
  Widget _list() => LayoutBuilder(
    builder: (context, box) {
      final card = box.maxWidth < 900 || _card;
      final visible = _rows.skip(_page * _pageSize).take(_pageSize).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title([
            if (box.maxWidth >= 900)
              IconButton(
                tooltip: 'สลับ List/Card',
                onPressed: () => setState(() => _card = !_card),
                icon: Icon(
                  _card ? Icons.table_rows_outlined : Icons.grid_view,
                  color: _primary,
                ),
              ),
            if (_actions['create'] == true)
              FilledButton.icon(
                style: receiptButton(_primary),
                onPressed: _busy ? null : _new,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              ),
          ], surfaceKey: const ValueKey('stock-receipt-caption-card')),
          const SizedBox(height: 6),
          _surface(
            LayoutBuilder(
              builder: (_, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 260
                        ? constraints.maxWidth
                        : 260,
                    child: TextField(
                      key: const ValueKey('stock-receipt-search-filter'),
                      controller: _search,
                      style: const TextStyle(
                        fontSize: LaooTypography.inputText,
                      ),
                      decoration: receiptInput(
                        'ค้นหาเลขที่ / อ้างอิง / หมายเหตุ / ผู้ส่งมอบ',
                        _primary,
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 280
                        ? constraints.maxWidth
                        : 280,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('stock-receipt-vendor-filter-$_listVendor'),
                      initialValue: _listVendor,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: LaooTypography.comboBox,
                        color: LaooColors.textPrimary,
                      ),
                      decoration: receiptInput('ผู้ขาย', _primary).copyWith(
                        prefixIcon: IconButton(
                          tooltip: 'ค้นหาผู้ขาย',
                          onPressed: _busy ? null : _findListVendor,
                          icon: Icon(Icons.search, color: _primary),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                        for (final vendor in _vendors)
                          DropdownMenuItem<int>(
                            value: (vendor['vendorID'] as num).toInt(),
                            child: Text(
                              '${vendor['vendorCode']} | ${vendor['vendorName']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _listVendor = value),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 280
                        ? constraints.maxWidth
                        : 280,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(
                        'stock-receipt-warehouse-filter-$_listWarehouse',
                      ),
                      initialValue: _listWarehouse,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: LaooTypography.comboBox,
                        color: LaooColors.textPrimary,
                      ),
                      decoration: receiptInput('คลัง', _primary),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                        for (final warehouse in _warehouses)
                          DropdownMenuItem<int>(
                            value: (warehouse['warehouseID'] as num).toInt(),
                            child: Text(
                              '${warehouse['warehouseCode']} | ${warehouse['warehouseName']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _listWarehouse = value),
                    ),
                  ),
                  FilledButton(
                    style: receiptButton(_primary, compact: true),
                    onPressed: _busy ? null : _load,
                    child: const Text('ค้นหา'),
                  ),
                  OutlinedButton(
                    style: receiptButton(_primary, compact: true),
                    onPressed: _busy
                        ? null
                        : () {
                            _search.clear();
                            _listVendor = null;
                            _listWarehouse = null;
                            _load();
                          },
                    child: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ),
            key: const ValueKey('stock-receipt-filter-card'),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: _rows.isEmpty
                ? _surface(
                    const Center(child: Text('ไม่พบรายการ')),
                    key: const ValueKey('stock-receipt-empty-card'),
                  )
                : card
                ? ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final r = visible[i];
                      return _surface(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_page * _pageSize + i + 1}. ${r['receiptCode']}',
                            ),
                            Text(
                              '${r['warehouseCode']} | ${r['warehouseName']}',
                            ),
                            Text(_listDate(r['receiptDate'])),
                            Text('${r['vendorName'] ?? '-'}'),
                            Text('${r['statusCode']}'),
                            _rowActions(r),
                          ],
                        ),
                      );
                    },
                  )
                : _surface(
                    LayoutBuilder(
                      builder: (_, constraints) => SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: LaooColors.border),
                              child: DataTable(
                                dividerThickness: 1,
                                showBottomBorder: true,
                                headingTextStyle: TextStyle(
                                  fontSize: LaooTypography.tableHeader,
                                  color: _primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                dataTextStyle: const TextStyle(
                                  fontSize: LaooTypography.tableBody,
                                  color: Colors.black,
                                ),
                                headingRowColor: WidgetStatePropertyAll(
                                  _primary.withValues(alpha: .1),
                                ),
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Action')),
                                  DataColumn(label: Text('เลขที่')),
                                  DataColumn(label: Text('วันที่')),
                                  DataColumn(label: Text('ผู้ขาย')),
                                  DataColumn(label: Text('คลัง')),
                                  DataColumn(label: Text('ประเภท')),
                                  DataColumn(label: Text('จำนวน')),
                                  DataColumn(label: Text('สถานะ')),
                                ],
                                rows: [
                                  for (var i = 0; i < visible.length; i++)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Text('${_page * _pageSize + i + 1}'),
                                        ),
                                        DataCell(_rowActions(visible[i])),
                                        for (final key in [
                                          'receiptCode',
                                          'receiptDate',
                                          'vendorName',
                                          'warehouseName',
                                          'receiptType',
                                          'totalQuantity',
                                          'statusCode',
                                        ])
                                          DataCell(
                                            Text(
                                              key == 'receiptDate'
                                                  ? _listDate(visible[i][key])
                                                  : '${visible[i][key] ?? '-'}',
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    key: const ValueKey('stock-receipt-table-card'),
                  ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          SizedBox(
            height: LaooLayout.paginationCardHeight,
            child: _surface(
              Row(
                children: [
                  _pageButton(
                    const Icon(Icons.chevron_left, size: 18),
                    _page > 0 ? () => setState(() => _page--) : null,
                  ),
                  const SizedBox(width: 6),
                  _pageButton(Text('${_page + 1}'), () {}, current: true),
                  const SizedBox(width: 6),
                  _pageButton(
                    const Icon(Icons.chevron_right, size: 18),
                    (_page + 1) * _pageSize < _rows.length
                        ? () => setState(() => _page++)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '${_rows.isEmpty ? 0 : _page * _pageSize + 1}-${_page * _pageSize + visible.length} จาก ${_rows.length}',
                    ),
                  ),
                ],
              ),
              key: const ValueKey('stock-receipt-pagination-card'),
            ),
          ),
        ],
      );
    },
  );
  Widget _rowActions(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'เปิดเอกสาร',
        onPressed: _busy ? null : () => _open(row),
        icon: Icon(Icons.open_in_new, color: _primary),
      ),
      if (_actions['edit'] == true && row['statusCode'] == 'DRAFT')
        IconButton(
          tooltip: 'ยืนยันเข้าสต๊อก',
          onPressed: _busy ? null : () => _confirm(row),
          icon: Icon(Icons.check_circle_outline, color: _primary),
        ),
    ],
  );
  Widget _pageButton(
    Widget child,
    VoidCallback? onPressed, {
    bool current = false,
  }) => SizedBox(
    width: 34,
    height: 34,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        backgroundColor: current ? _primary : Colors.white,
        foregroundColor: current ? Colors.white : _primary,
        side: BorderSide(color: onPressed == null ? Colors.grey : _primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      ),
      child: child,
    ),
  );

  Future<void> _pickReceiptDate() async {
    final theme = Theme.of(context);
    final primary = _primary;
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: _usesBuddhistYear
          ? const Locale('th', 'TH')
          : const Locale('en', 'US'),
      builder: (context, child) => Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: LaooColors.textPrimary,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: Colors.white,
            headerForegroundColor: LaooColors.textPrimary,
            headerHeadlineStyle: theme.textTheme.headlineMedium?.copyWith(
              color: LaooColors.textPrimary,
            ),
            headerHelpStyle: theme.textTheme.labelLarge?.copyWith(
              color: LaooColors.textSecondary,
            ),
            weekdayStyle: theme.textTheme.bodySmall?.copyWith(
              color: LaooColors.textPrimary,
            ),
            dayStyle: theme.textTheme.bodyMedium?.copyWith(
              color: LaooColors.textPrimary,
            ),
            dayForegroundColor: WidgetStatePropertyAll(LaooColors.textPrimary),
            dayOverlayColor: WidgetStatePropertyAll(
              primary.withValues(alpha: 0.12),
            ),
            todayForegroundColor: WidgetStatePropertyAll(primary),
            todayBorder: BorderSide(color: primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Widget _editor() => Form(
    key: _form,
    child: ListView(
      children: [
        _title(
          [
            OutlinedButton(
              style: receiptButton(_primary),
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _editing = false);
                      _load();
                    },
              child: const Text('กลับรายการ'),
            ),
            if (_editable)
              FilledButton.icon(
                style: receiptButton(_primary),
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_busy ? 'กำลังบันทึก' : 'บันทึก'),
              ),
          ],
          suffix: _id == null
              ? ' > เพิ่ม'
              : _editable
              ? ' > แก้ไข'
              : ' > ดูข้อมูล',
        ),
        const SizedBox(height: LaooLayout.cardSpacing),
        _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('สถานะ: $_status'),
              const SizedBox(height: 12),
              _three(
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: receiptInput('ประเภท *', _primary),
                  items: const [
                    DropdownMenuItem(
                      value: 'RECEIPT',
                      child: Text('รับสินค้า'),
                    ),
                    DropdownMenuItem(value: 'OPENING', child: Text('ยอดยกมา')),
                  ],
                  onChanged: !_editable || _busy
                      ? null
                      : (v) => setState(() => _type = v!),
                ),
                TextFormField(
                  key: ValueKey(_code),
                  initialValue: _code.isEmpty ? 'สร้างอัตโนมัติ' : _code,
                  readOnly: true,
                  decoration: receiptInput('เลขที่เอกสาร', _primary),
                ),
                TextFormField(
                  key: ValueKey(_date),
                  initialValue: _displayDate(_date),
                  readOnly: true,
                  decoration: receiptInput('วันที่รับ *', _primary).copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: !_editable || _busy ? null : _pickReceiptDate,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _combo(
                      _type == 'RECEIPT' ? 'ผู้ขาย *' : 'ผู้ขาย',
                      _vendor,
                      _vendors,
                      'vendor',
                      (v) => setState(() => _vendor = v),
                      required: _type == 'RECEIPT',
                    ),
                  ),
                  if (_createVendor &&
                      widget.onCreateVendor != null &&
                      _editable)
                    IconButton(
                      tooltip: 'เพิ่มผู้ขาย',
                      onPressed: _busy ? null : _addVendor,
                      icon: Icon(Icons.person_add_alt_1, color: _primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _three(
                _combo(
                  'คลัง *',
                  _warehouse,
                  _warehouses,
                  'warehouse',
                  (v) => setState(() => _warehouse = v),
                  required: true,
                ),
                _text(_reference, 'อ้างอิงเอกสารผู้ขาย', 100),
                _text(_delivered, 'ผู้ส่งมอบ', 200),
              ),
              const SizedBox(height: 12),
              _text(_remark, 'หมายเหตุ', 1000),
            ],
          ),
        ),
        const SizedBox(height: LaooLayout.cardSpacing),
        _detailSection(),
      ],
    ),
  );

  Widget _detailSection() => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('stock-receipt-detail-section-header'),
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'รายการสินค้า (${_lines.length})',
                  style: const TextStyle(
                    fontSize: LaooTypography.sectionTitle,
                    fontWeight: LaooTypography.emphasizedWeight,
                    color: LaooColors.textPrimary,
                  ),
                ),
              ),
              if (_editable)
                OutlinedButton.icon(
                  style: receiptButton(_primary),
                  onPressed: _busy || _items.isEmpty
                      ? null
                      : () => setState(
                          () => _lines.add(ReceiptDraftLine(_items.first)),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มรายการ'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 900;
            return Column(
              children: [
                if (!narrow) _detailHeader(),
                if (_lines.isEmpty)
                  Container(
                    key: const ValueKey('stock-receipt-detail-empty'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: const Text(
                      'ยังไม่มีรายการสินค้า',
                      style: TextStyle(
                        fontSize: LaooTypography.body,
                        color: LaooColors.textSecondary,
                      ),
                    ),
                  ),
                for (var i = 0; i < _lines.length; i++)
                  Container(
                    key: ValueKey('stock-receipt-detail-row-$i'),
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: narrow ? 6 : 0),
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow ? LaooLayout.cardPadding : 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: narrow
                          ? _primary.withValues(alpha: 0.035)
                          : Colors.white,
                      borderRadius: narrow
                          ? BorderRadius.circular(LaooRadius.xs)
                          : null,
                      border: narrow
                          ? null
                          : const Border(
                              bottom: BorderSide(color: LaooColors.border),
                            ),
                    ),
                    child: _detail(i, _lines[i], narrow),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Container(
          key: const ValueKey('stock-receipt-detail-footer'),
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                'รวม ${_lines.length} รายการ',
                style: const TextStyle(
                  fontSize: LaooTypography.body,
                  color: LaooColors.textSecondary,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'มูลค่ารวม  '),
                    TextSpan(
                      text:
                          '${_lines.fold<double>(0, (sum, l) => sum + l.amount).toStringAsFixed(2)} บาท',
                      style: TextStyle(
                        color: _primary,
                        fontSize: LaooTypography.sectionTitle,
                        fontWeight: LaooTypography.emphasizedWeight,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: LaooTypography.body,
                  fontWeight: LaooTypography.emphasizedWeight,
                  color: LaooColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _pair(Widget left, Widget right) => LayoutBuilder(
    builder: (_, box) => box.maxWidth < 600
        ? Column(children: [left, const SizedBox(height: 12), right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              Expanded(child: right),
            ],
          ),
  );
  Widget _three(Widget first, Widget second, Widget third) => LayoutBuilder(
    builder: (_, box) => box.maxWidth < 850
        ? Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
              const SizedBox(height: 12),
              third,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
              const SizedBox(width: 12),
              Expanded(child: third),
            ],
          ),
  );
  Widget _text(TextEditingController c, String label, int max) => TextFormField(
    controller: c,
    enabled: _editable && !_busy,
    style: const TextStyle(fontSize: LaooTypography.inputText),
    decoration: receiptInput(label, _primary),
    maxLength: max,
    buildCounter:
        (_, {required currentLength, required isFocused, maxLength}) => null,
  );
  Widget _combo(
    String label,
    int? selected,
    List<Map<String, dynamic>> values,
    String prefix,
    ValueChanged<int?> changed, {
    bool required = false,
    bool tableInput = false,
  }) {
    final rows = [...values];
    if (selected != null && !rows.any((r) => r['${prefix}ID'] == selected)) {
      rows.add({
        '${prefix}ID': selected,
        '${prefix}Code': '',
        '${prefix}Name': 'รายการเดิม (ไม่เปิดใช้งาน)',
      });
    }
    return DropdownButtonFormField<int>(
      key: ValueKey('$prefix-$selected-${rows.length}'),
      initialValue: selected,
      isExpanded: true,
      style: const TextStyle(
        fontSize: LaooTypography.comboBox,
        color: Colors.black,
      ),
      decoration:
          (tableInput
                  ? receiptTableInput(_primary)
                  : receiptInput(label, _primary))
              .copyWith(
                prefixIcon: _editable && !_busy
                    ? IconButton(
                        tooltip: 'ค้นหา$label',
                        onPressed: () async {
                          final id = await showDialog<int>(
                            context: context,
                            builder: (_) => ReceiptLookupDialog(
                              label: label,
                              rows: values,
                              prefix: prefix,
                            ),
                          );
                          if (id != null && mounted) changed(id);
                        },
                        icon: Icon(Icons.search, color: _primary),
                      )
                    : null,
              ),
      items: [
        if (!required)
          const DropdownMenuItem<int>(value: null, child: Text('ไม่ระบุ')),
        for (final r in rows)
          DropdownMenuItem(
            value: (r['${prefix}ID'] as num).toInt(),
            child: Text(
              '${r['${prefix}Code']} | ${r['${prefix}Name']}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (v) => required && v == null ? 'กรุณาเลือก$label' : null,
      onChanged: _editable && !_busy ? changed : null,
    );
  }

  Widget _detailHeader() => Container(
    key: const ValueKey('stock-receipt-detail-table-header'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: Row(
      children: [
        const SizedBox(width: 36, child: Center(child: Text('ID'))),
        const SizedBox(width: 48, child: Center(child: Text('Action'))),
        for (final pair in [
          ('สินค้า', 4),
          ('หน่วย', 2),
          ('จำนวน', 2),
          ('ต้นทุน/หน่วย', 2),
          ('รวม', 2),
          ('Serial', 2),
        ])
          Expanded(
            flex: pair.$2,
            child: Text(
              pair.$1,
              style: TextStyle(
                color: _primary,
                fontSize: LaooTypography.tableHeader,
                fontWeight: LaooTypography.emphasizedWeight,
              ),
            ),
          ),
      ],
    ),
  );
  Widget _detail(int index, ReceiptDraftLine l, bool narrow) {
    final item = _combo(
      'สินค้า *',
      l.itemId,
      _items,
      'item',
      (v) {
        setState(() => l.setItem(_items.firstWhere((x) => x['itemID'] == v)));
      },
      required: true,
      tableInput: !narrow,
    );
    final unit = DropdownButtonFormField<String>(
      key: ValueKey('receipt-unit-${l.itemId}-${l.unit}'),
      initialValue: l.unit,
      isExpanded: true,
      decoration: narrow
          ? receiptInput('หน่วยรับ *', _primary)
          : receiptTableInput(_primary),
      style: const TextStyle(
        fontSize: LaooTypography.inputText,
        color: Colors.black87,
      ),
      items: l.units
          .map(
            (u) => DropdownMenuItem<String>(
              value: '${u['unitCode']}',
              child: Text(
                '${u['unitName'] ?? u['unitCode']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: !_editable || _busy
          ? null
          : (value) => setState(() {
              if (value == null || value == l.unit) return;
              l.selectUnit(value);
              l.setSerials([]);
            }),
    );
    final unitField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        unit,
        if (l.conversionFactor != 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'เข้าสต๊อก ${l.baseQtyText} ${l.baseUnitName}',
              style: TextStyle(
                color: _primary,
                fontSize: LaooTypography.bodySmall,
              ),
            ),
          ),
      ],
    );
    Widget number(
      TextEditingController c,
      String label, {
      bool quantity = false,
    }) => TextFormField(
      controller: c,
      enabled: _editable && !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: LaooTypography.inputText),
      decoration: narrow
          ? receiptInput(label, _primary)
          : receiptTableInput(_primary),
      onChanged: (_) => setState(() {
        if (quantity) l.serialConfirmed = false;
        if (quantity &&
            l.source == 'INTERNAL' &&
            l.numbers.isNotEmpty &&
            l.numbers.length != l.baseQty) {
          l.setSerials([]);
        }
      }),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        if (n == null || !n.isFinite || n < 0 || (quantity && n <= 0)) {
          return 'ระบุตัวเลข${quantity ? 'มากกว่า 0' : ''}';
        }
        final baseQuantity = n * l.conversionFactor;
        if (quantity &&
            l.serial &&
            (baseQuantity != baseQuantity.truncateToDouble() ||
                baseQuantity > 2000)) {
          return 'จำนวนเต็ม 1–2000';
        }
        return null;
      },
    );
    final delete = IconButton(
      tooltip: 'ลบรายการ ${index + 1}',
      onPressed: !_editable || _busy
          ? null
          : () => setState(() {
              _lines.remove(l);
              l.dispose();
            }),
      icon: const Icon(Icons.delete_outline, color: Colors.red),
    );
    final progress = l.serial
        ? '${l.source == 'INTERNAL' && l.serialValues.isEmpty ? 'สร้าง' : l.serialValues.where((x) => x.trim().isNotEmpty).length}/${l.baseQty.toInt()}'
        : '—';
    final serial = TextButton(
      onPressed: !l.serial || _busy
          ? null
          : () async {
              if (l.baseQty <= 0 ||
                  l.baseQty > 2000 ||
                  l.baseQty != l.baseQty.truncateToDouble()) {
                return;
              }
              final previousSource = l.source;
              final previousSerials = List<String>.from(l.serialValues);
              final wasConfirmed = l.serialConfirmed;
              l.resizeSerials();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) =>
                    ReceiptSerialDialog(lines: [l], readOnly: !_editable),
              );
              if (confirmed == true) {
                l.serialConfirmed = true;
              } else {
                l.source = previousSource;
                l.setSerials(previousSerials, confirmed: wasConfirmed);
              }
              if (mounted) setState(() {});
            },
      child: Text(progress),
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('ID ${index + 1}')),
              delete,
            ],
          ),
          item,
          const SizedBox(height: 12),
          unitField,
          const SizedBox(height: 12),
          _pair(
            number(l.quantity, 'จำนวน *', quantity: true),
            number(l.cost, 'ต้นทุน/หน่วย'),
          ),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [Text('รวม: ${l.amount.toStringAsFixed(2)}'), serial],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: Text('${index + 1}')),
          ),
        ),
        SizedBox(width: 48, child: Center(child: delete)),
        Expanded(flex: 4, child: item),
        Expanded(flex: 2, child: unitField),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: number(l.quantity, 'จำนวน', quantity: true),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: number(l.cost, 'ต้นทุน'),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l.amount.toStringAsFixed(2),
              style: const TextStyle(
                fontWeight: LaooTypography.emphasizedWeight,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(alignment: Alignment.centerLeft, child: serial),
        ),
      ],
    );
  }
}

InputDecoration receiptInput(String label, Color primary) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border(LaooColors.border),
    enabledBorder: border(LaooColors.border),
    disabledBorder: border(LaooColors.border),
    focusedBorder: border(primary),
    errorBorder: border(Colors.red),
    focusedErrorBorder: border(Colors.red),
  );
}

InputDecoration receiptTableInput(Color primary) => receiptInput(
  '',
  primary,
).copyWith(labelText: null, floatingLabelBehavior: FloatingLabelBehavior.never);

ButtonStyle receiptButton(Color primary, {bool compact = false}) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(
    Size(0, compact ? 40 : LaooTypography.buttonHeight),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(LaooRadius.xs)),
  ),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(fontSize: LaooTypography.button),
  ),
);

class ReceiptLookupDialog extends StatefulWidget {
  const ReceiptLookupDialog({
    super.key,
    required this.label,
    required this.rows,
    required this.prefix,
  });
  final String label, prefix;
  final List<Map<String, dynamic>> rows;
  @override
  State<ReceiptLookupDialog> createState() => _ReceiptLookupDialogState();
}

class _ReceiptLookupDialogState extends State<ReceiptLookupDialog> {
  final _search = TextEditingController();
  String _query = '';
  String? _itemTypeCode;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isItemLookup = widget.prefix == 'item';
    String name(Map<String, dynamic> r) =>
        '${r['${widget.prefix}Code']} | ${r['${widget.prefix}Name']}';
    String typeName(Map<String, dynamic> r) {
      final code = r['itemTypeCode']?.toString().trim() ?? '';
      final label = r['itemTypeName']?.toString().trim() ?? '';
      return label.isEmpty ? code : '$code | $label';
    }

    final types = <String, String>{
      for (final row in widget.rows)
        if ((row['itemTypeCode']?.toString().trim() ?? '').isNotEmpty)
          row['itemTypeCode'].toString(): typeName(row),
    };
    final rows = widget.rows
        .where(
          (r) =>
              name(r).toLowerCase().contains(_query) &&
              (!isItemLookup ||
                  _itemTypeCode == null ||
                  r['itemTypeCode']?.toString() == _itemTypeCode),
        )
        .toList();
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: SizedBox(
        width: isItemLookup ? 820 : 480,
        height: MediaQuery.sizeOf(context).height * .65,
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.search, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ค้นหา${widget.label.replaceAll('*', '').trim()}',
                      style: const TextStyle(
                        fontSize: LaooTypography.workspaceCaption,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: LaooColors.border),
              LayoutBuilder(
                builder: (_, box) {
                  final search = TextField(
                    controller: _search,
                    autofocus: true,
                    style: const TextStyle(fontSize: LaooTypography.inputText),
                    decoration: receiptInput('รหัส / ชื่อ', primary).copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'ค้นหา',
                        onPressed: () => setState(
                          () => _query = _search.text.trim().toLowerCase(),
                        ),
                        icon: Icon(Icons.search, color: primary),
                      ),
                    ),
                    onSubmitted: (_) => setState(
                      () => _query = _search.text.trim().toLowerCase(),
                    ),
                  );
                  if (!isItemLookup) return search;
                  final typeFilter = DropdownButtonFormField<String>(
                    key: const ValueKey('item-lookup-type-filter'),
                    initialValue: _itemTypeCode,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: LaooTypography.comboBox,
                      color: LaooColors.textPrimary,
                    ),
                    decoration: receiptInput('ประเภทสินค้า', primary),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      for (final entry in types.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _itemTypeCode = value),
                  );
                  if (box.maxWidth < 600) {
                    return Column(
                      children: [
                        search,
                        const SizedBox(height: 12),
                        typeFilter,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: search),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: typeFilter),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('ไม่พบรายการ'))
                    : isItemLookup
                    ? _itemResults(rows, name, typeName, primary)
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(
                            name(rows[i]),
                            style: const TextStyle(
                              fontSize: LaooTypography.comboBox,
                            ),
                          ),
                          onTap: () => _select(rows[i]),
                        ),
                      ),
              ),
              const Divider(color: LaooColors.border),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  style: receiptButton(primary),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemResults(
    List<Map<String, dynamic>> rows,
    String Function(Map<String, dynamic>) name,
    String Function(Map<String, dynamic>) typeName,
    Color primary,
  ) => LayoutBuilder(
    builder: (_, box) {
      final narrow = box.maxWidth < 600;
      return Column(
        children: [
          if (!narrow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text('รูปภาพ', style: _headerStyle(primary)),
                  ),
                  Expanded(child: Text('สินค้า', style: _headerStyle(primary))),
                  SizedBox(
                    width: 180,
                    child: Text('ประเภทสินค้า', style: _headerStyle(primary)),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('หน่วย', style: _headerStyle(primary)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: LaooColors.border),
              itemBuilder: (_, i) => narrow
                  ? ListTile(
                      leading: _imageThumbnail(rows[i], primary),
                      title: Text(name(rows[i])),
                      subtitle: Text(
                        '${typeName(rows[i])} • ${rows[i]['unitCode'] ?? '-'}',
                      ),
                      onTap: () => _select(rows[i]),
                    )
                  : InkWell(
                      onTap: () => _select(rows[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: _imageThumbnail(rows[i], primary),
                            ),
                            Expanded(
                              child: Text(
                                name(rows[i]),
                                style: const TextStyle(
                                  fontSize: LaooTypography.comboBox,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: Text(typeName(rows[i])),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text('${rows[i]['unitCode'] ?? '-'}'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      );
    },
  );

  TextStyle _headerStyle(Color primary) => TextStyle(
    color: primary,
    fontSize: LaooTypography.tableHeader,
    fontWeight: LaooTypography.emphasizedWeight,
  );

  Widget _imageThumbnail(Map<String, dynamic> row, Color primary) {
    final bytes = _imageBytes(row['coverImageBase64']);
    if (bytes == null) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: Icon(Icons.image_not_supported_outlined, color: primary),
      );
    }
    return Tooltip(
      message: 'ดูรูปภาพ',
      child: InkWell(
        onTap: () => _previewImage(
          name: '${row['itemCode']} | ${row['itemName']}',
          bytes: bytes,
        ),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Uint8List? _imageBytes(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    try {
      return base64Decode(text);
    } on FormatException {
      return null;
    }
  }

  Future<void> _previewImage({
    required String name,
    required Uint8List bytes,
  }) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: LaooTypography.workspaceCaption,
                        fontWeight: LaooTypography.emphasizedWeight,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: LaooColors.border),
              Flexible(child: Image.memory(bytes, fit: BoxFit.contain)),
              const Divider(color: LaooColors.border),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  style: receiptButton(Theme.of(context).colorScheme.primary),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _select(Map<String, dynamic> row) =>
      Navigator.pop(context, (row['${widget.prefix}ID'] as num).toInt());
}

class ReceiptDraftLine {
  ReceiptDraftLine(Map<String, dynamic> item) {
    setItem(item);
  }
  late int itemId;
  String name = '', unit = '', baseUnit = '', baseUnitName = '';
  String source = 'FACTORY';
  double conversionFactor = 1;
  List<Map<String, dynamic>> units = [];
  String? remark;
  bool serial = false, serialConfirmed = false;
  final quantity = TextEditingController(text: '1'),
      cost = TextEditingController(text: '0');
  final List<TextEditingController> numbers = [];
  double get qty {
    final n = double.tryParse(quantity.text);
    return n != null && n.isFinite ? n : 0;
  }

  double get amount {
    final n = double.tryParse(cost.text);
    return n != null && n.isFinite ? qty * n : 0;
  }

  double get baseQty => qty * conversionFactor;
  String get baseQtyText => baseQty == baseQty.truncateToDouble()
      ? baseQty.toInt().toString()
      : baseQty.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');

  List<String> get serialValues => numbers.map((c) => c.text.trim()).toList();
  void setItem(Map<String, dynamic> item) {
    itemId = (item['itemID'] as num).toInt();
    name = '${item['itemCode']} | ${item['itemName']}';
    baseUnit = '${item['unitCode'] ?? ''}';
    baseUnitName = '${item['unitName'] ?? baseUnit}';
    units = (item['receiptUnits'] as List? ?? const [])
        .map((u) => Map<String, dynamic>.from(u as Map))
        .toList();
    if (units.isEmpty) {
      units = [
        {
          'unitCode': baseUnit,
          'unitName': baseUnitName,
          'conversionFactor': 1,
          'isBaseUnit': true,
        },
      ];
    }
    unit = baseUnit;
    conversionFactor = 1;
    serial = item['stockTrackingCode'] == 'SERIAL';
    source = 'FACTORY';
    setSerials([]);
  }

  void selectUnit(
    String code, {
    double? snapshotFactor,
    String? snapshotBaseUnit,
  }) {
    final matches = units.where((u) => '${u['unitCode']}' == code);
    Map<String, dynamic> selected;
    if (matches.isEmpty) {
      selected = {
        'unitCode': code,
        'unitName': code,
        'conversionFactor': snapshotFactor ?? 1,
        'isBaseUnit': false,
      };
      units.add(selected);
    } else {
      selected = matches.first;
    }
    unit = code;
    conversionFactor =
        snapshotFactor ??
        (selected['conversionFactor'] as num?)?.toDouble() ??
        1;
    if (snapshotBaseUnit != null && snapshotBaseUnit.isNotEmpty) {
      baseUnit = snapshotBaseUnit;
    }
  }

  void setSerials(List<String> values, {bool confirmed = false}) {
    for (final c in numbers) {
      c.dispose();
    }
    numbers.clear();
    numbers.addAll(values.map((v) => TextEditingController(text: v)));
    serialConfirmed = serial && confirmed;
  }

  void resizeSerials() {
    if (source == 'INTERNAL' && numbers.isEmpty) return;
    final size = baseQty.toInt().clamp(0, 2000);
    if (numbers.length != size) serialConfirmed = false;
    while (numbers.length > size) {
      numbers.removeLast().dispose();
    }
    while (numbers.length < size) {
      numbers.add(TextEditingController());
    }
  }

  Map<String, dynamic> get body => {
    'itemID': itemId,
    'quantity': qty,
    'unitCode': unit,
    'unitCost': double.tryParse(cost.text) ?? 0,
    'remark': remark,
    'serialSourceCode': source,
    'serials': serialValues.map((s) => {'serialNo': s}).toList(),
  };
  void dispose() {
    quantity.dispose();
    cost.dispose();
    for (final c in numbers) {
      c.dispose();
    }
  }
}

class ReceiptSerialDialog extends StatefulWidget {
  const ReceiptSerialDialog({
    super.key,
    required this.lines,
    this.onSave,
    this.readOnly = false,
  });
  final List<ReceiptDraftLine> lines;
  final Future<bool> Function()? onSave;
  final bool readOnly;
  @override
  State<ReceiptSerialDialog> createState() => _ReceiptSerialDialogState();
}

class _ReceiptSerialDialogState extends State<ReceiptSerialDialog> {
  final _form = GlobalKey<FormState>();
  bool _saving = false, _saved = false;

  Set<String> get _duplicateSerials {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final line in widget.lines) {
      for (final serial in line.serialValues) {
        final normalized = serial.trim().toUpperCase();
        if (normalized.isEmpty) continue;
        if (!seen.add(normalized)) duplicates.add(normalized);
      }
    }
    return duplicates;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final duplicateSerials = _duplicateSerials;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: SizedBox(
          width: 480,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height - 48,
            ),
            child: Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code, color: primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Serial สินค้ารับเข้า',
                          style: TextStyle(
                            fontSize: LaooTypography.workspaceCaption,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: LaooColors.border),
                  Flexible(
                    child: Form(
                      key: _form,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final l in widget.lines) ...[
                              Container(
                                key: ValueKey(
                                  'receipt-serial-item-header-${widget.lines.indexOf(l)}',
                                ),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.name,
                                      style: TextStyle(
                                        fontSize: LaooTypography.sectionTitle,
                                        fontWeight:
                                            LaooTypography.emphasizedWeight,
                                        color: primary,
                                      ),
                                    ),
                                    Text(
                                      'จำนวน ${l.baseQty.toInt()} ${l.baseUnitName}',
                                      style: TextStyle(
                                        fontSize: LaooTypography.body,
                                        color: primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: l.source,
                                isExpanded: true,
                                decoration: receiptInput(
                                  'รูปแบบ Serial',
                                  primary,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'FACTORY',
                                    child: Text('Serial จากโรงงาน'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'INTERNAL',
                                    child: Text('สร้างเลขภายใน'),
                                  ),
                                ],
                                onChanged: _saving || _saved || widget.readOnly
                                    ? null
                                    : (v) => setState(() {
                                        l.source = v!;
                                        l.setSerials([]);
                                        l.resizeSerials();
                                      }),
                              ),
                              const SizedBox(height: 12),
                              if (l.source == 'INTERNAL' && l.numbers.isEmpty)
                                Text(
                                  'ระบบจะสร้าง Serial ${l.baseQty.toInt()} หมายเลขเมื่อบันทึกเอกสาร',
                                ),
                              for (var i = 0; i < l.numbers.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextFormField(
                                    key: ValueKey(
                                      'receipt-serial-${widget.lines.indexOf(l)}-$i',
                                    ),
                                    controller: l.numbers[i],
                                    readOnly:
                                        l.source == 'INTERNAL' ||
                                        _saving ||
                                        _saved ||
                                        widget.readOnly,
                                    style: const TextStyle(
                                      fontSize: LaooTypography.inputText,
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    decoration:
                                        receiptInput(
                                          'Serial ${i + 1} *',
                                          primary,
                                        ).copyWith(
                                          errorText:
                                              duplicateSerials.contains(
                                                l.numbers[i].text
                                                    .trim()
                                                    .toUpperCase(),
                                              )
                                              ? 'Serial ซ้ำในเอกสาร'
                                              : null,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context).nextFocus(),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      final value = v?.trim() ?? '';
                                      if (value.isEmpty || value.length > 200) {
                                        return 'ระบุ Serial 1–200 ตัวอักษร';
                                      }
                                      return duplicateSerials.contains(
                                            value.toUpperCase(),
                                          )
                                          ? 'Serial ซ้ำในเอกสาร'
                                          : null;
                                    },
                                  ),
                                ),
                              Text(
                                'ระบุ ${l.serialValues.where((v) => v.isNotEmpty).length}/${l.baseQty.toInt()}',
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: LaooColors.border),
                  if (_saved)
                    const Text('บันทึกเป็นเอกสารร่างแล้ว ยังไม่เพิ่มยอดสต๊อก'),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onSave != null && !_saved && !widget.readOnly)
                        OutlinedButton(
                          style: receiptButton(primary),
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('กลับไปแก้ไข'),
                        ),
                      if (!_saved && !widget.readOnly)
                        FilledButton(
                          style: receiptButton(primary),
                          onPressed: _saving
                              ? null
                              : () async {
                                  if (!_form.currentState!.validate()) return;
                                  if (widget.onSave == null) {
                                    Navigator.pop(context, true);
                                    return;
                                  }
                                  setState(() => _saving = true);
                                  final success = await widget.onSave!();
                                  if (mounted) {
                                    setState(() {
                                      _saving = false;
                                      _saved = success;
                                    });
                                  }
                                },
                          child: Text(_saving ? 'กำลังบันทึก' : 'ยืนยัน'),
                        ),
                      if (widget.onSave == null && !widget.readOnly)
                        OutlinedButton(
                          style: receiptButton(primary),
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('ปิด'),
                        ),
                      if (_saved || widget.readOnly)
                        OutlinedButton(
                          style: receiptButton(primary),
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('ปิด'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
