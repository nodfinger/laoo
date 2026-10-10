import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';

class PurchaseTaxInvoicePage extends StatefulWidget {
  const PurchaseTaxInvoicePage({super.key});
  @override
  State<PurchaseTaxInvoicePage> createState() => _PurchaseTaxInvoicePageState();
}

class _PurchaseTaxInvoicePageState extends State<PurchaseTaxInvoicePage> {
  final _api = ApiClient();
  final _supplier = TextEditingController();
  final _vendorBranch = TextEditingController(text: '00000');
  final _reason = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  String _caption = 'ใบกำกับภาษีซื้อ';
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _branches = [];
  Map<String, bool> _actions = {};
  int? _vendorId, _branchId, _editingId;
  String _claim = 'ELIGIBLE';
  int _taxRate = 7;
  DateTime _invoiceDate = DateTime.now(), _receivedDate = DateTime.now();
  int _taxYear = DateTime.now().year, _taxMonth = DateTime.now().month;
  bool _loading = true, _saving = false, _form = false, _card = false;
  int _page = 0;
  final List<Map<String, dynamic>> _lines = [];
  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  int get _pages => math.max(1, (_rows.length / _pageSize).ceil());
  List<Map<String, dynamic>> get _visible =>
      _rows.skip(_page * _pageSize).take(_pageSize).toList();
  Color get _accent => workspaceThemeController.value.primary;

  @override
  void initState() {
    super.initState();
    _resolve();
    _load();
  }

  Future<void> _resolve() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: 'companyPurchaseTaxInvoices',
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = name);
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _api.get('/api/company/purchase-tax-invoices'),
        _api.get('/api/company/purchase-tax-invoices/lookup'),
        _api.get('/api/company/purchase-tax-invoices/actions'),
      ]);
      if (!mounted) return;
      final lookup = Map<String, dynamic>.from(values[1] as Map);
      setState(() {
        _rows = (values[0] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        _vendors = (lookup['vendors'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        _branches = (lookup['branches'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        _actions = Map<String, dynamic>.from(
          values[2] as Map,
        ).map((k, v) => MapEntry(k, v == true));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _notify('โหลดข้อมูลไม่ได้', e);
    }
  }

  void _notify(String message, Object detail, {bool error = true}) =>
      showTimedSnackBar(
        context,
        message: '$message\nรายละเอียดเพิ่มเติม: $detail',
        error: error,
      );
  void _new() {
    setState(() {
      _form = true;
      _editingId = null;
      _supplier.clear();
      _vendorBranch.text = '00000';
      _reason.clear();
      _description.clear();
      _quantity.text = '1';
      _price.clear();
      _vendorId = null;
      _branchId = null;
      _claim = 'ELIGIBLE';
      _taxRate = 7;
      _invoiceDate = DateTime.now();
      _receivedDate = DateTime.now();
      _taxYear = DateTime.now().year;
      _taxMonth = DateTime.now().month;
      _lines.clear();
    });
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/purchase-tax-invoices/${row['purchaseTaxInvoiceId']}',
            )
            as Map,
      );
      final h = Map<String, dynamic>.from(data['header'] as Map);
      if (!mounted) return;
      setState(() {
        _form = true;
        _editingId = (h['purchaseTaxInvoiceId'] as num).toInt();
        _supplier.text = '${h['supplierInvoiceCode']}';
        _vendorBranch.text = '${h['vendorTaxBranchCode'] ?? ''}';
        _reason.text = '${h['claimReason'] ?? ''}';
        _vendorId = (h['vendorId'] as num).toInt();
        _branchId = (h['branchId'] as num?)?.toInt();
        _claim = '${h['claimStatus']}';
        _taxRate = (h['taxRate'] as num).toInt();
        _invoiceDate = DateTime.parse('${h['invoiceDate']}');
        _receivedDate = DateTime.parse('${h['receivedDate']}');
        _taxYear = (h['taxYear'] as num).toInt();
        _taxMonth = (h['taxMonth'] as num).toInt();
        _lines
          ..clear()
          ..addAll(
            (data['lines'] as List).map(
              (v) => Map<String, dynamic>.from(v as Map),
            ),
          );
      });
    } catch (e) {
      if (mounted) _notify('เปิดเอกสารไม่ได้', e);
    }
  }

  Future<void> _pick(bool invoice) async {
    final date = await showDatePicker(
      context: context,
      initialDate: invoice ? _invoiceDate : _receivedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (date != null) {
      setState(() {
        if (invoice) {
          _invoiceDate = date;
        } else {
          _receivedDate = date;
        }
      });
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void _addLine() {
    final qty = double.tryParse(_quantity.text),
        price = double.tryParse(_price.text);
    if (_description.text.trim().isEmpty ||
        qty == null ||
        qty <= 0 ||
        price == null ||
        price < 0) {
      _notify(
        'รายการไม่ถูกต้อง',
        'กรอกรายละเอียด จำนวนมากกว่า 0 และราคาที่ไม่ติดลบ',
      );
      return;
    }
    setState(() {
      _lines.add({
        'description': _description.text.trim(),
        'quantity': qty,
        'unitPrice': price,
      });
      _description.clear();
      _quantity.text = '1';
      _price.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_vendorId == null ||
        _branchId == null ||
        _supplier.text.trim().isEmpty ||
        _lines.isEmpty ||
        (_claim != 'ELIGIBLE' && _reason.text.trim().isEmpty)) {
      _notify(
        'ข้อมูลไม่ครบ',
        'เลือกผู้ขาย สาขา เลขใบผู้ขาย และเพิ่มรายการอย่างน้อยหนึ่งรายการ',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = Map<String, dynamic>.from(
        await _api.post(
              '/api/company/purchase-tax-invoices',
              body: {
                'purchaseTaxInvoiceId': _editingId,
                'vendorId': _vendorId,
                'branchId': _branchId,
                'vendorTaxBranchCode': _vendorBranch.text.trim(),
                'supplierInvoiceCode': _supplier.text.trim(),
                'invoiceDate': _iso(_invoiceDate),
                'receivedDate': _iso(_receivedDate),
                'taxYear': _taxYear,
                'taxMonth': _taxMonth,
                'taxRate': _taxRate,
                'claimStatus': _claim,
                'claimReason': _reason.text.trim(),
                'lines': _lines,
              },
            )
            as Map,
      );
      if (!mounted) return;
      setState(() {
        _editingId = (result['purchaseTaxInvoiceId'] as num).toInt();
        _form = false;
      });
      _notify(
        'บันทึกร่างแล้ว',
        'ตรวจข้อมูลและกดยืนยันเพื่อเข้ารายงานภาษี',
        error: false,
      );
      await _load();
    } catch (e) {
      if (mounted) _notify('บันทึกไม่ได้', e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> row) async {
    try {
      await _api.post(
        '/api/company/purchase-tax-invoices/${row['purchaseTaxInvoiceId']}/confirm',
      );
      if (!mounted) return;
      _notify(
        'ยืนยันใบกำกับภาษีซื้อแล้ว',
        'เอกสารเข้ารายงานตามเดือนภาษีที่กำหนด',
        error: false,
      );
      await _load();
    } catch (e) {
      if (mounted) _notify('ยืนยันไม่ได้', e);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: const BorderSide(color: LaooColors.error),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Text('ยืนยันการลบ', style: TextStyle(color: LaooColors.error)),
          ],
        ),
        content: Text(
          'ลบ ${row['internalCode']} · ${row['supplierInvoiceCode']}\nข้อมูลนี้ไม่สามารถเรียกคืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: LaooColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: () => Navigator.pop(dialog, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete(
        '/api/company/purchase-tax-invoices/${row['purchaseTaxInvoiceId']}',
      );
      if (!mounted) return;
      _notify('ลบเอกสารร่างแล้ว', row['internalCode'] ?? '', error: false);
      await _load();
    } catch (e) {
      if (mounted) _notify('ลบไม่ได้', e);
    }
  }

  Widget _surface(Widget child, {double? height}) => Container(
    width: double.infinity,
    height: height,
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );
  InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
  Widget _input(TextEditingController c, String label, {bool number = false}) =>
      SizedBox(
        width: 240,
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: _field(label),
        ),
      );
  Widget _formView() => Column(
    children: [
      _surface(
        Row(
          children: [
            Expanded(
              child: WorkspacePageTitle(
                title: _caption,
                favoriteKey: 'companyPurchaseTaxInvoices',
                titleColor: LaooColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _form = false),
              child: const Text('ยกเลิก'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Header · ข้อมูลใบกำกับภาษีซื้อ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey((_editingId, _vendorId)),
                    initialValue: _vendorId,
                    decoration: _field('ผู้ขาย *'),
                    items: _vendors
                        .map(
                          (v) => DropdownMenuItem(
                            value: (v['vendorId'] as num).toInt(),
                            child: Text(
                              '${v['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _vendorId = v),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey((_editingId, _branchId)),
                    initialValue: _branchId,
                    decoration: _field('สาขาบริษัท *'),
                    items: _branches
                        .map(
                          (v) => DropdownMenuItem(
                            value: (v['branchId'] as num).toInt(),
                            child: Text(
                              '${v['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _branchId = v),
                  ),
                ),
                _input(_supplier, 'เลขใบกำกับฯ ผู้ขาย *'),
                _input(_vendorBranch, 'รหัสสาขาผู้ขาย 5 หลัก'),
                OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text('วันที่ใบ ${_iso(_invoiceDate)}'),
                ),
                OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text('วันที่รับ ${_iso(_receivedDate)}'),
                ),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    key: ValueKey((_editingId, _taxYear)),
                    initialValue: '$_taxYear',
                    decoration: _field('ปีภาษี'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _taxYear = int.tryParse(v) ?? _taxYear,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey((_editingId, _taxMonth)),
                    initialValue: _taxMonth,
                    decoration: _field('เดือนภาษี'),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) setState(() => _taxMonth = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey((_editingId, _claim)),
                    initialValue: _claim,
                    decoration: _field('สิทธิ์ภาษีซื้อ'),
                    items: const [
                      DropdownMenuItem(
                        value: 'ELIGIBLE',
                        child: Text('หักได้'),
                      ),
                      DropdownMenuItem(
                        value: 'INELIGIBLE',
                        child: Text('หักไม่ได้'),
                      ),
                      DropdownMenuItem(value: 'REVIEW', child: Text('รอตรวจ')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _claim = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey((_editingId, _taxRate)),
                    initialValue: _taxRate,
                    decoration: _field('อัตรา VAT'),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7%')),
                      DropdownMenuItem(value: 0, child: Text('0%')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _taxRate = v);
                    },
                  ),
                ),
                if (_claim != 'ELIGIBLE') _input(_reason, 'เหตุผล *'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail · รายการสินค้า/บริการ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _input(_description, 'รายละเอียด *'),
                _input(_quantity, 'จำนวน *', number: true),
                _input(_price, 'ราคาต่อหน่วย *', number: true),
                OutlinedButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มรายการ'),
                ),
              ],
            ),
            ..._lines.indexed.map(
              (e) => ListTile(
                title: Text('${e.$1 + 1}. ${e.$2['description']}'),
                subtitle: Text('${e.$2['quantity']} × ${e.$2['unitPrice']}'),
                trailing: IconButton(
                  onPressed: () => setState(() => _lines.removeAt(e.$1)),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: LaooColors.error,
                  ),
                ),
              ),
            ),
            const Divider(),
            Text(
              'ก่อนภาษี ${_lines.fold<double>(0, (sum, x) => sum + ((x['quantity'] as num) * (x['unitPrice'] as num)).toDouble()).toStringAsFixed(2)} · VAT $_taxRate%',
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      _surface(
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('บันทึกร่าง'),
          ),
        ),
      ),
    ],
  );
  Widget _listView(bool compact) => Column(
    children: [
      _surface(
        Row(
          children: [
            Expanded(
              child: WorkspacePageTitle(
                title: _caption,
                favoriteKey: 'companyPurchaseTaxInvoices',
                titleColor: LaooColors.textPrimary,
              ),
            ),
            if (!compact)
              IconButton(
                onPressed: () => setState(() => _card = !_card),
                icon: Icon(
                  _card ? Icons.view_list_outlined : Icons.grid_view_outlined,
                ),
                color: _accent,
              ),
            if (_actions['create'] == true)
              FilledButton.icon(
                onPressed: _new,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      _surface(
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
            ? const Center(child: Text('ไม่มีข้อมูล'))
            : (compact || _card)
            ? Column(
                children: _visible
                    .map(
                      (r) => ListTile(
                        title: Text(
                          '${r['internalCode']} · ${r['supplierInvoiceCode']}',
                        ),
                        subtitle: Text(
                          '${r['vendorName']} · ${r['statusCode']} · VAT ${r['taxAmount']}',
                        ),
                        onTap: _actions['view'] == true ? () => _edit(r) : null,
                        trailing: r['statusCode'] == 'DRAFT'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_actions['edit'] == true)
                                    IconButton(
                                      onPressed: () => _confirm(r),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                    ),
                                  if (_actions['delete'] == true)
                                    IconButton(
                                      onPressed: () => _delete(r),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: LaooColors.error,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    )
                    .toList(),
              )
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(constraints.maxWidth, 1100),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('ทะเบียนภายใน')),
                        DataColumn(label: Text('เลขผู้ขาย')),
                        DataColumn(label: Text('ผู้ขาย')),
                        DataColumn(label: Text('ก่อนภาษี'), numeric: true),
                        DataColumn(label: Text('ภาษี'), numeric: true),
                        DataColumn(label: Text('สถานะ')),
                      ],
                      rows: _visible.indexed.map((e) {
                        final r = e.$2;
                        return DataRow(
                          cells: [
                            DataCell(Text('${e.$1 + 1 + _page * _pageSize}')),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _actions['view'] == true
                                        ? () => _edit(r)
                                        : null,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: _accent,
                                    ),
                                  ),
                                  if (_actions['edit'] == true &&
                                      r['statusCode'] == 'DRAFT')
                                    IconButton(
                                      onPressed: () => _confirm(r),
                                      icon: Icon(
                                        Icons.check_circle_outline,
                                        color: _accent,
                                      ),
                                    ),
                                  if (_actions['delete'] == true &&
                                      r['statusCode'] == 'DRAFT')
                                    IconButton(
                                      onPressed: () => _delete(r),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: LaooColors.error,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text('${r['internalCode']}')),
                            DataCell(Text('${r['supplierInvoiceCode']}')),
                            DataCell(Text('${r['vendorName']}')),
                            DataCell(Text('${r['taxBase']}')),
                            DataCell(Text('${r['taxAmount']}')),
                            DataCell(Text('${r['statusCode']}')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ),
      const SizedBox(height: 6),
      _surface(
        Row(
          children: [
            IconButton(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_page + 1}'),
            IconButton(
              onPressed: _page + 1 < _pages
                  ? () => setState(() => _page++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 12),
            Text(
              '${_rows.isEmpty ? 0 : _page * _pageSize + 1}-${math.min((_page + 1) * _pageSize, _rows.length)} จาก ${_rows.length}',
            ),
          ],
        ),
        height: LaooLayout.paginationCardHeight,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'companyPurchaseTaxInvoices',
    menuScope: WorkspaceMenuScope.company,
    child: LayoutBuilder(
      builder: (context, size) => ListView(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        children: [_form ? _formView() : _listView(size.maxWidth < 900)],
      ),
    ),
  );
  @override
  void dispose() {
    _api.dispose();
    _supplier.dispose();
    _vendorBranch.dispose();
    _reason.dispose();
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }
}
