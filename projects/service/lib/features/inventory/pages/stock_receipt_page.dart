import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
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
  int? _id, _warehouse, _vendor;
  int _page = 0;
  static const _pageSize = 10;
  String _type = 'RECEIPT', _code = '', _status = 'DRAFT';
  DateTime _date = DateTime.now();
  Color get _primary => Theme.of(context).colorScheme.primary;
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
        _api.receipts(search: _search.text),
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
          final l = ReceiptDraftLine(item)
            ..quantity.text = '${item['quantity']}'
            ..cost.text = '${item['unitCost']}'
            ..source = item['serialSourceCode'] ?? 'FACTORY'
            ..remark = item['remark'];
          l.setSerials(
            serials
                .where(
                  (s) =>
                      s['stockReceiptDetailID'] == item['stockReceiptDetailID'],
                )
                .map((s) => '${s['serialNo']}')
                .toList(),
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
    if (_lines.where((l) => l.serial).fold<double>(0, (n, l) => n + l.qty) >
        2000) {
      _error('Serial รวมต้องไม่เกิน 2,000 ชิ้นต่อเอกสาร');
      return;
    }
    final serialLines = _lines.where((l) => l.serial).toList();
    if (serialLines.isNotEmpty) {
      for (final l in serialLines) {
        l.resizeSerials();
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
          line.setSerials(List<String>.from(raw['serials']));
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
  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );
  Widget _title(List<Widget> buttons, {String suffix = ''}) => _surface(
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
  );
  Widget _list() => LayoutBuilder(
    builder: (context, box) {
      final card = box.maxWidth < 900 || _card;
      final visible = _rows.skip(_page * _pageSize).take(_pageSize).toList();
      return Column(
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
          ]),
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
                      controller: _search,
                      style: const TextStyle(
                        fontSize: LaooTypography.inputText,
                      ),
                      decoration: receiptInput(
                        'ค้นหาเลขที่ / อ้างอิง',
                        _primary,
                      ),
                      onSubmitted: (_) => _load(),
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
                            _load();
                          },
                    child: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: _rows.isEmpty
                ? _surface(const Center(child: Text('ไม่พบรายการ')))
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
                            Text('${r['receiptDate']}'.split('T').first),
                            Text('${r['statusCode']}'),
                            _rowActions(r),
                          ],
                        ),
                      );
                    },
                  )
                : _surface(
                    SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
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
                                    'warehouseName',
                                    'receiptType',
                                    'totalQuantity',
                                    'statusCode',
                                  ])
                                    DataCell(
                                      Text(
                                        key == 'receiptDate'
                                            ? '${visible[i][key]}'
                                                  .split('T')
                                                  .first
                                            : '${visible[i][key]}',
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
              _pair(
                TextFormField(
                  key: ValueKey(_code),
                  initialValue: _code.isEmpty ? 'สร้างอัตโนมัติ' : _code,
                  readOnly: true,
                  decoration: receiptInput('เลขที่เอกสาร', _primary),
                ),
                TextFormField(
                  key: ValueKey(_date),
                  initialValue: _date.toIso8601String().substring(0, 10),
                  readOnly: true,
                  decoration: receiptInput('วันที่รับ *', _primary).copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: !_editable || _busy
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null && mounted) {
                            setState(() => _date = date);
                          }
                        },
                ),
              ),
              const SizedBox(height: 12),
              _pair(
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
                _combo(
                  'คลัง *',
                  _warehouse,
                  _warehouses,
                  'warehouse',
                  (v) => setState(() => _warehouse = v),
                  required: true,
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
              _pair(
                _text(_reference, 'อ้างอิงเอกสารผู้ขาย', 100),
                _text(_delivered, 'ผู้ส่งมอบ', 200),
              ),
              const SizedBox(height: 12),
              _text(_remark, 'หมายเหตุ', 1000),
            ],
          ),
        ),
        const SizedBox(height: LaooLayout.cardSpacing),
        _surface(
          Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('รายการสินค้า')),
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
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    if (box.maxWidth >= 900) _detailHeader(),
                    for (var i = 0; i < _lines.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _detail(i, _lines[i], box.maxWidth < 900),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'มูลค่ารวม ${_lines.fold<double>(0, (sum, l) => sum + l.amount).toStringAsFixed(2)} บาท',
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
      decoration: receiptInput(label, _primary).copyWith(
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

  Widget _detailHeader() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const SizedBox(width: 36, child: Text('ID')),
        const SizedBox(width: 48, child: Text('Action')),
        for (final pair in [
          ('สินค้า', 4),
          ('หน่วย', 1),
          ('จำนวน', 2),
          ('ต้นทุน/หน่วย', 2),
          ('รวม', 2),
          ('Serial', 2),
        ])
          Expanded(
            flex: pair.$2,
            child: Text(
              pair.$1,
              style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );
  Widget _detail(int index, ReceiptDraftLine l, bool narrow) {
    final item = _combo('สินค้า *', l.itemId, _items, 'item', (v) {
      setState(() => l.setItem(_items.firstWhere((x) => x['itemID'] == v)));
    }, required: true);
    Widget number(
      TextEditingController c,
      String label, {
      bool quantity = false,
    }) => TextFormField(
      controller: c,
      enabled: _editable && !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: LaooTypography.inputText),
      decoration: receiptInput(label, _primary),
      onChanged: (_) => setState(() {
        if (quantity &&
            l.source == 'INTERNAL' &&
            l.numbers.isNotEmpty &&
            l.numbers.length != l.qty) {
          l.setSerials([]);
        }
      }),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        if (n == null || !n.isFinite || n < 0 || (quantity && n <= 0)) {
          return 'ระบุตัวเลข${quantity ? 'มากกว่า 0' : ''}';
        }
        if (quantity && l.serial && (n != n.truncateToDouble() || n > 2000)) {
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
        ? '${l.source == 'INTERNAL' && l.serialValues.isEmpty ? 'สร้าง' : l.serialValues.where((x) => x.trim().isNotEmpty).length}/${l.qty.toInt()}'
        : '—';
    final serial = TextButton(
      onPressed: !l.serial || _busy
          ? null
          : () async {
              if (l.qty <= 0 ||
                  l.qty > 2000 ||
                  l.qty != l.qty.truncateToDouble()) {
                return;
              }
              l.resizeSerials();
              await showDialog<void>(
                context: context,
                builder: (_) =>
                    ReceiptSerialDialog(lines: [l], readOnly: !_editable),
              );
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
          _pair(
            number(l.quantity, 'จำนวน *', quantity: true),
            number(l.cost, 'ต้นทุน/หน่วย'),
          ),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('หน่วย: ${l.unit}'),
              Text('รวม: ${l.amount.toStringAsFixed(2)}'),
              serial,
            ],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 36, child: Text('${index + 1}')),
        SizedBox(width: 48, child: delete),
        Expanded(flex: 4, child: item),
        Expanded(child: Text(l.unit)),
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
        Expanded(flex: 2, child: Text(l.amount.toStringAsFixed(2))),
        Expanded(flex: 2, child: serial),
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
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    String name(Map<String, dynamic> r) =>
        '${r['${widget.prefix}Code']} | ${r['${widget.prefix}Name']}';
    final rows = widget.rows
        .where((r) => name(r).toLowerCase().contains(_query))
        .toList();
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: SizedBox(
        width: 480,
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
              TextField(
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
                onSubmitted: (_) =>
                    setState(() => _query = _search.text.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('ไม่พบรายการ'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(
                            name(rows[i]),
                            style: const TextStyle(
                              fontSize: LaooTypography.comboBox,
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            context,
                            (rows[i]['${widget.prefix}ID'] as num).toInt(),
                          ),
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
}

class ReceiptDraftLine {
  ReceiptDraftLine(Map<String, dynamic> item) {
    setItem(item);
  }
  late int itemId;
  String name = '', unit = '', source = 'FACTORY';
  String? remark;
  bool serial = false;
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

  List<String> get serialValues => numbers.map((c) => c.text.trim()).toList();
  void setItem(Map<String, dynamic> item) {
    itemId = (item['itemID'] as num).toInt();
    name = '${item['itemCode']} | ${item['itemName']}';
    unit = '${item['unitCode'] ?? ''}';
    serial = item['stockTrackingCode'] == 'SERIAL';
    source = 'FACTORY';
    setSerials([]);
  }

  void setSerials(List<String> values) {
    for (final c in numbers) {
      c.dispose();
    }
    numbers.clear();
    numbers.addAll(values.map((v) => TextEditingController(text: v)));
  }

  void resizeSerials() {
    if (source == 'INTERNAL' && numbers.isEmpty) return;
    final size = qty.toInt().clamp(0, 2000);
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
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${l.name} • ${l.qty.toInt()} ชิ้น',
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
                                  'ระบบจะสร้าง Serial ${l.qty.toInt()} หมายเลขเมื่อบันทึกเอกสาร',
                                ),
                              for (var i = 0; i < l.numbers.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextFormField(
                                    controller: l.numbers[i],
                                    readOnly:
                                        l.source == 'INTERNAL' ||
                                        _saving ||
                                        _saved ||
                                        widget.readOnly,
                                    style: const TextStyle(
                                      fontSize: LaooTypography.inputText,
                                    ),
                                    decoration: receiptInput(
                                      'Serial ${i + 1} *',
                                      primary,
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
                                      final count = widget.lines
                                          .expand((l) => l.serialValues)
                                          .where(
                                            (s) =>
                                                s.toUpperCase() ==
                                                value.toUpperCase(),
                                          )
                                          .length;
                                      return count > 1
                                          ? 'Serial ซ้ำในเอกสาร'
                                          : null;
                                    },
                                  ),
                                ),
                              Text(
                                'ระบุ ${l.serialValues.where((v) => v.isNotEmpty).length}/${l.qty.toInt()}',
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
                      OutlinedButton(
                        style: receiptButton(primary),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          _saved || widget.readOnly
                              ? 'กลับเอกสาร'
                              : 'กลับไปแก้ไข',
                        ),
                      ),
                      if (widget.onSave != null && !_saved && !widget.readOnly)
                        FilledButton(
                          style: receiptButton(primary),
                          onPressed: _saving
                              ? null
                              : () async {
                                  if (!_form.currentState!.validate()) return;
                                  setState(() => _saving = true);
                                  final success = await widget.onSave!();
                                  if (mounted) {
                                    setState(() {
                                      _saving = false;
                                      _saved = success;
                                    });
                                  }
                                },
                          child: Text(_saving ? 'กำลังบันทึก' : 'บันทึกเอกสาร'),
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
