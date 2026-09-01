import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../app/theme/laoo_typography.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/tax_invoice_api.dart';

class TaxInvoicePage extends StatelessWidget {
  const TaxInvoicePage({this.action = false, this.taxInvoiceId, super.key});
  final bool action;
  final int? taxInvoiceId;

  @override
  Widget build(BuildContext context) => action
      ? _TaxInvoiceActionPage(taxInvoiceId: taxInvoiceId)
      : const _TaxInvoiceListPage();
}

class _TaxInvoiceListPage extends StatefulWidget {
  const _TaxInvoiceListPage();
  @override
  State<_TaxInvoiceListPage> createState() => _TaxInvoiceListPageState();
}

class _TaxInvoiceListPageState extends State<_TaxInvoiceListPage> {
  static const _activeMenu = 'companyTaxInvoices';
  final _api = TaxInvoiceApi();
  final _profile = UserProfileRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  Map<String, bool> _actions = const {};
  String _menuName = 'ใบกำกับภาษี';
  String _status = 'ALL';
  String _reference = 'ALL';
  bool _loading = true;
  bool _card = false;
  int _page = 0;

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  int get _pages => math.max(1, (_rows.length / _pageSize).ceil());
  List<Map<String, dynamic>> get _visible => _rows
      .skip(_page.clamp(0, _pages - 1) * _pageSize)
      .take(_pageSize)
      .toList();

  @override
  void initState() {
    super.initState();
    _resolveName();
    _defaultView();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _resolveName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        routeName: _activeMenu,
        fallback: 'ใบกำกับภาษี',
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  Future<void> _defaultView() async {
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
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.list(
          search: _search.text,
          status: _status,
          referenceType: _reference,
        ),
        _api.actions(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (values[0] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _actions = Map<String, bool>.from(
          (values[1] as Map).map(
            (key, value) => MapEntry('$key', value == true),
          ),
        );
        _page = _page.clamp(0, _pages - 1);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error('โหลดรายการใบกำกับภาษีไม่ได้', e);
    }
  }

  void _error(String message, Object e) => showTimedSnackBar(
    context,
    message: '$message\nรายละเอียด: $e',
    error: true,
  );

  String _date(dynamic value) {
    final d = DateTime.tryParse('$value');
    return d == null
        ? '-'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _money(dynamic value) => (num.tryParse('$value') ?? 0)
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String _statusName(dynamic value) => switch ('$value') {
    'DRAFT' => 'ร่าง',
    'ISSUED' => 'ออกแล้ว',
    'VOID' => 'ยกเลิก',
    _ => '$value',
  };

  Widget _surface({required Widget child, double? height}) => Container(
    height: height,
    width: double.infinity,
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  void _open({int? id}) => context.go(
    '/company/tax-invoices?action=${id == null ? 'new' : 'edit'}${id == null ? '' : '&id=$id'}',
  );

  Future<void> _delete(Map<String, dynamic> row) async {
    final accent = workspaceThemeController.value.primary;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Text('ยืนยันการลบข้อมูล', style: LaooTypography.screenCaptionStyle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              child: Text(
                'ต้องการลบ ${row['taxInvoiceCode']} - ${row['customerName']} หรือไม่?',
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('ยกเลิก', style: TextStyle(color: accent)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: LaooColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.delete((row['taxInvoiceId'] as num).toInt());
      await _load();
    } catch (e) {
      if (mounted) _error('ลบใบกำกับภาษีไม่ได้', e);
    }
  }

  Widget _rowActions(Map<String, dynamic> row, Color accent) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'เปิดดู/แก้ไข',
        onPressed: _actions['view'] == true
            ? () => _open(id: (row['taxInvoiceId'] as num).toInt())
            : null,
        icon: Icon(Icons.edit_outlined, color: accent),
      ),
      IconButton(
        tooltip: 'ลบ',
        onPressed: _actions['delete'] == true && row['statusCode'] == 'DRAFT'
            ? () => _delete(row)
            : null,
        icon: const Icon(Icons.delete_outline, color: LaooColors.error),
      ),
    ],
  );

  Widget _cardRow(Map<String, dynamic> row, Color accent) => _surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${row['taxInvoiceCode']} | ${_date(row['taxInvoiceDate'])}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
            _rowActions(row, accent),
          ],
        ),
        Text('${row['customerCode']} | ${row['customerName']}'),
        const SizedBox(height: 6),
        Text(
          'อ้างอิง ${('${row['referenceCode']}').isEmpty ? '-' : row['referenceCode']} | ยอดสุทธิ ${_money(row['netAmount'])} | ${_statusName(row['statusCode'])}',
        ),
      ],
    ),
  );

  Widget _table(Color accent, double width) => _surface(
    child: SizedBox(
      width: width,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(accent.withValues(alpha: .10)),
        dividerThickness: .5,
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('เลขที่เอกสาร')),
          DataColumn(label: Text('วันที่')),
          DataColumn(label: Text('ลูกค้า')),
          DataColumn(label: Text('อ้างอิง')),
          DataColumn(label: Text('ยอดสุทธิ'), numeric: true),
          DataColumn(label: Text('สถานะ')),
        ],
        rows: _visible.indexed.map((entry) {
          final row = entry.$2;
          return DataRow(
            cells: [
              DataCell(Text('${entry.$1 + 1 + _page * _pageSize}')),
              DataCell(_rowActions(row, accent)),
              DataCell(Text('${row['taxInvoiceCode']}')),
              DataCell(Text(_date(row['taxInvoiceDate']))),
              DataCell(Text('${row['customerCode']} | ${row['customerName']}')),
              DataCell(
                Text(
                  ('${row['referenceCode']}').isEmpty
                      ? '-'
                      : '${row['referenceCode']}',
                ),
              ),
              DataCell(Text(_money(row['netAmount']))),
              DataCell(Text(_statusName(row['statusCode']))),
            ],
          );
        }).toList(),
      ),
    ),
  );

  Widget _pagination(Color accent) => _surface(
    height: LaooLayout.paginationCardHeight,
    child: Row(
      children: [
        _pageButton(
          icon: Icons.chevron_left,
          onTap: _page > 0 ? () => setState(() => _page--) : null,
        ),
        const SizedBox(width: 4),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: Text(
            '${_page + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 4),
        _pageButton(
          icon: Icons.chevron_right,
          onTap: _page + 1 < _pages ? () => setState(() => _page++) : null,
        ),
        const SizedBox(width: 8),
        Text(
          '${_rows.isEmpty ? 0 : _page * _pageSize + 1}-${math.min((_page + 1) * _pageSize, _rows.length)} จาก ${_rows.length}',
        ),
      ],
    ),
  );

  Widget _pageButton({required IconData icon, VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    child: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Icon(icon, color: Colors.grey),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu: _activeMenu,
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final cardMode = compact || _card;
            return ListView(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              children: [
                _surface(
                  child: Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _menuName,
                          favoriteKey: _activeMenu,
                          titleColor: Colors.black,
                        ),
                      ),
                      if (!compact) ...[
                        IconButton(
                          onPressed: () => setState(() => _card = !_card),
                          style: IconButton.styleFrom(
                            foregroundColor: accent,
                            backgroundColor: accent.withValues(alpha: .10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          icon: Icon(
                            cardMode
                                ? Icons.view_list_outlined
                                : Icons.grid_view_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        onPressed: _actions['create'] == true
                            ? () => _open()
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มเอกสาร'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _surface(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: compact ? constraints.maxWidth : 340,
                        child: TextField(
                          controller: _search,
                          onSubmitted: (_) => _load(),
                          decoration: const InputDecoration(
                            labelText: 'ค้นหาเลขที่เอกสาร/ลูกค้า',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      _filterCombo(
                        width: compact ? constraints.maxWidth : 210,
                        label: 'อ้างอิง',
                        value: _reference,
                        values: const {
                          'ALL': 'ทั้งหมด',
                          'NONE': 'ไม่อ้างอิง',
                          'QUOTATION': 'ใบเสนอราคา',
                          'PREORDER': 'ใบรับจองสินค้า',
                          'TEMP_RECEIPT': 'ใบเสร็จรับเงินชั่วคราว',
                        },
                        onChanged: (v) =>
                            setState(() => _reference = v ?? 'ALL'),
                      ),
                      _filterCombo(
                        width: compact ? constraints.maxWidth : 180,
                        label: 'สถานะ',
                        value: _status,
                        values: const {
                          'ALL': 'ทั้งหมด',
                          'DRAFT': 'ร่าง',
                          'ISSUED': 'ออกแล้ว',
                          'VOID': 'ยกเลิก',
                        },
                        onChanged: (v) => setState(() => _status = v ?? 'ALL'),
                      ),
                      FilledButton.icon(
                        onPressed: _load,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('ค้นหา'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (cardMode)
                  ..._visible.expand(
                    (row) => [_cardRow(row, accent), const SizedBox(height: 6)],
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _table(accent, constraints.maxWidth),
                  ),
                const SizedBox(height: 8),
                _pagination(accent),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterCombo({
    required double width,
    required String label,
    required String value,
    required Map<String, String> values,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values.entries
          .map(
            (e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
}

class _TaxInvoiceActionPage extends StatefulWidget {
  const _TaxInvoiceActionPage({this.taxInvoiceId});
  final int? taxInvoiceId;
  @override
  State<_TaxInvoiceActionPage> createState() => _TaxInvoiceActionPageState();
}

class _TaxInvoiceActionPageState extends State<_TaxInvoiceActionPage> {
  static const _activeMenu = 'companyTaxInvoices';
  final _api = TaxInvoiceApi();
  final _formKey = GlobalKey<FormState>();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _contactEmail = TextEditingController();
  final _paymentType = TextEditingController();
  final _creditDays = TextEditingController(text: '0');
  final _discountPercent = TextEditingController(text: '0');
  final _discountAmount = TextEditingController(text: '0');
  final _taxPercent = TextEditingController(text: '7');
  final _remark = TextEditingController();
  Map<String, dynamic> _lookup = const {};
  Map<String, bool> _actions = const {};
  List<Map<String, dynamic>> _lines = [];
  String _menuName = 'ใบกำกับภาษี';
  String _referenceType = 'NONE';
  int? _referenceId;
  int? _customerId;
  int? _id;
  String _code = '';
  String _status = 'DRAFT';
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  bool get _editable => _status == 'DRAFT';
  List<Map<String, dynamic>> get _customers => _maps(_lookup['customers']);
  List<Map<String, dynamic>> get _items => _maps(_lookup['items']);
  List<Map<String, dynamic>> get _references => switch (_referenceType) {
    'QUOTATION' => _maps(_lookup['quotations']),
    'PREORDER' => _maps(_lookup['preOrders']),
    'TEMP_RECEIPT' => _maps(_lookup['receipts']),
    _ => const [],
  };
  Map<String, dynamic>? get _customer =>
      _customers.cast<Map<String, dynamic>?>().firstWhere(
        (e) => (e?['customerId'] as num?)?.toInt() == _customerId,
        orElse: () => null,
      );

  double get _subtotal =>
      _lines.fold(0, (sum, line) => sum + _lineAmount(line));
  double get _headerDiscount {
    final percent = _number(_discountPercent.text);
    return percent > 0
        ? _subtotal * percent / 100
        : _number(_discountAmount.text);
  }

  double get _afterDiscount => math.max(0, _subtotal - _headerDiscount);
  double get _taxAmount => _afterDiscount * _number(_taxPercent.text) / 100;
  double get _netAmount => _afterDiscount + _taxAmount;

  @override
  void initState() {
    super.initState();
    _id = widget.taxInvoiceId;
    _resolveName();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    for (final c in [
      _contactName,
      _contactPhone,
      _contactEmail,
      _paymentType,
      _creditDays,
      _discountPercent,
      _discountAmount,
      _taxPercent,
      _remark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _resolveName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        routeName: _activeMenu,
        fallback: 'ใบกำกับภาษี',
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final lookup = await _api.lookup();
      final actions = await _api.actions();
      Map<String, dynamic>? document;
      if (_id != null) document = await _api.get(_id!);
      if (!mounted) return;
      setState(() {
        _lookup = lookup;
        _actions = actions;
        if (document != null) _applyDocument(document);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error('เปิดหน้าใบกำกับภาษีไม่ได้', e);
    }
  }

  void _applyDocument(Map<String, dynamic> document) {
    final h = Map<String, dynamic>.from(document['header'] as Map);
    _id = (h['taxInvoiceId'] as num).toInt();
    _code = '${h['taxInvoiceCode']}';
    _date = DateTime.tryParse('${h['taxInvoiceDate']}') ?? DateTime.now();
    _referenceType = '${h['referenceType']}';
    _referenceId = (h['referenceId'] as num?)?.toInt();
    _customerId = (h['customerId'] as num?)?.toInt();
    _status = '${h['statusCode']}';
    _contactName.text = '${h['contactName'] ?? ''}';
    _contactPhone.text = '${h['contactPhone'] ?? ''}';
    _contactEmail.text = '${h['contactEmail'] ?? ''}';
    _paymentType.text = '${h['paymentType'] ?? ''}';
    _creditDays.text = '${h['creditDays'] ?? 0}';
    _discountPercent.text = '${h['discountPercent'] ?? 0}';
    _discountAmount.text = '${h['discountAmount'] ?? 0}';
    _taxPercent.text = '${h['taxPercent'] ?? 7}';
    _remark.text = '${h['remark'] ?? ''}';
    _lines = _maps(document['items']);
  }

  Future<void> _loadSource(int id) async {
    try {
      final value = await _api.source(_referenceType, id);
      if (!mounted) return;
      final customer = Map<String, dynamic>.from(value['customer'] as Map);
      setState(() {
        _customerId = (customer['customerId'] as num).toInt();
        _contactName.text = '${customer['contactName'] ?? ''}';
        _contactPhone.text = '${customer['contactPhone'] ?? ''}';
        _contactEmail.text = '${customer['contactEmail'] ?? ''}';
        _paymentType.text = '${customer['paymentType'] ?? ''}';
        _creditDays.text = '${customer['creditDays'] ?? 0}';
        _taxPercent.text = '${value['taxPercent'] ?? 7}';
        _discountPercent.text = '${value['discountPercent'] ?? 0}';
        _discountAmount.text = '${value['discountAmount'] ?? 0}';
        _lines = _maps(value['items']);
      });
    } catch (e) {
      if (mounted) _error('อ่านเอกสารอ้างอิงไม่ได้', e);
    }
  }

  void _customerChanged(int? value) {
    setState(() {
      _customerId = value;
      final customer = _customers.firstWhere(
        (e) => (e['customerId'] as num).toInt() == value,
        orElse: () => const {},
      );
      _contactName.text = '${customer['contactName1'] ?? ''}';
      _contactPhone.text = '${customer['phone1'] ?? ''}';
      _contactEmail.text = '${customer['email1'] ?? ''}';
      _paymentType.text = '${customer['paymentType'] ?? ''}';
      _creditDays.text = '${customer['creditDays'] ?? 0}';
    });
  }

  Future<void> _editLine({int? index}) async {
    final accent = workspaceThemeController.value.primary;
    final current = index == null ? <String, dynamic>{} : _lines[index];
    int? itemId = (current['itemId'] as num?)?.toInt();
    final quantity = TextEditingController(text: '${current['quantity'] ?? 1}');
    final price = TextEditingController(text: '${current['unitPrice'] ?? 0}');
    final discountPercent = TextEditingController(
      text: '${current['discountPercent'] ?? 0}',
    );
    final discountAmount = TextEditingController(
      text: '${current['discountAmount'] ?? 0}',
    );
    String discountType = '${current['discountType'] ?? 'N'}';
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: accent),
              const SizedBox(width: 8),
              Text(index == null ? 'เพิ่มรายการสินค้า' : 'แก้ไขรายการสินค้า'),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: itemId,
                    decoration: const InputDecoration(labelText: '* สินค้า'),
                    items: _items
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: (e['itemId'] as num).toInt(),
                            child: Text('${e['itemCode']} | ${e['itemName']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => itemId = v);
                      final item = _items.firstWhere(
                        (e) => (e['itemId'] as num).toInt() == v,
                        orElse: () => const {},
                      );
                      price.text = '${item['unitPrice'] ?? 0}';
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numberField(quantity, '* จำนวน')),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(price, '* ราคา')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: discountType,
                    decoration: const InputDecoration(
                      labelText: 'รูปแบบส่วนลด',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'N', child: Text('ไม่มีส่วนลด')),
                      DropdownMenuItem(value: 'P', child: Text('เปอร์เซ็นต์')),
                      DropdownMenuItem(value: 'A', child: Text('จำนวนเงิน')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => discountType = v ?? 'N'),
                  ),
                  const SizedBox(height: 12),
                  if (discountType == 'P')
                    _numberField(discountPercent, 'ส่วนลด %')
                  else if (discountType == 'A')
                    _numberField(discountAmount, 'ส่วนลดจำนวนเงิน'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('ยกเลิก', style: TextStyle(color: accent)),
            ),
            FilledButton(
              onPressed: itemId == null
                  ? null
                  : () {
                      final item = _items.firstWhere(
                        (e) => (e['itemId'] as num).toInt() == itemId,
                      );
                      Navigator.pop(dialogContext, {
                        ...current,
                        'itemId': itemId,
                        'itemCode': item['itemCode'],
                        'itemName': item['itemName'],
                        'unitCode': item['unitCode'],
                        'unitName': item['unitName'],
                        'quantity': _number(quantity.text),
                        'unitPrice': _number(price.text),
                        'discountType': discountType,
                        'discountPercent': _number(discountPercent.text),
                        'discountAmount': _number(discountAmount.text),
                      });
                    },
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    price.dispose();
    discountPercent.dispose();
    discountAmount.dispose();
    if (saved == null || !mounted) return;
    if (_number('${saved['quantity']}') <= 0 ||
        _number('${saved['unitPrice']}') < 0) {
      _error(
        'ข้อมูลรายการสินค้าไม่ถูกต้อง',
        'จำนวนต้องมากกว่า 0 และราคาต้องไม่ติดลบ',
      );
      return;
    }
    setState(() {
      if (index == null) {
        _lines.add(saved);
      } else {
        _lines[index] = saved;
      }
    });
  }

  Future<void> _removeLine(int index) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Text('ยืนยันการลบข้อมูล', style: LaooTypography.screenCaptionStyle),
          ],
        ),
        content: Text(
          'ต้องการลบ ${_lines[index]['itemCode']} - ${_lines[index]['itemName']} หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: LaooColors.error),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes == true) setState(() => _lines.removeAt(index));
  }

  Future<void> _save() async {
    if (!_editable || _saving) return;
    if (!_formKey.currentState!.validate() ||
        _customerId == null ||
        _lines.isEmpty) {
      _error(
        'บันทึกใบกำกับภาษีไม่ได้',
        'กรุณากรอกข้อมูลบังคับ เลือกลูกค้า และเพิ่มสินค้าอย่างน้อย 1 รายการ',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'taxInvoiceDate': _date.toIso8601String(),
        'referenceType': _referenceType,
        'referenceId': _referenceType == 'NONE' ? null : _referenceId,
        'customerId': _customerId,
        'contactName': _contactName.text,
        'contactPhone': _contactPhone.text,
        'contactEmail': _contactEmail.text,
        'paymentType': _paymentType.text,
        'creditDays': _int(_creditDays.text),
        'discountPercent': _number(_discountPercent.text),
        'discountAmount': _number(_discountAmount.text),
        'taxPercent': _number(_taxPercent.text),
        'remark': _remark.text,
        'items': _lines
            .map(
              (line) => {
                'itemId': line['itemId'],
                'quotationDetailId': line['quotationDetailId'],
                'preOrderDetailId': line['preOrderDetailId'],
                'quantity': _number('${line['quantity']}'),
                'unitPrice': _number('${line['unitPrice']}'),
                'discountType': line['discountType'] ?? 'N',
                'discountPercent': _number('${line['discountPercent']}'),
                'discountAmount': _number('${line['discountAmount']}'),
                'remark': line['remark'],
              },
            )
            .toList(),
      };
      final result = _id == null
          ? await _api.create(body)
          : await _api.update(_id!, body);
      if (!mounted) return;
      setState(() {
        _id = (result['taxInvoiceId'] as num).toInt();
        _code = '${result['taxInvoiceCode']}';
        _saving = false;
      });
      showTimedSnackBar(context, message: 'บันทึกข้อมูลใบกำกับภาษีสำเร็จ');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error('บันทึกใบกำกับภาษีไม่ได้', e);
    }
  }

  Future<void> _issue() async {
    if (_id == null) {
      await _save();
      if (_id == null) return;
    }
    try {
      await _api.issue(_id!);
      if (!mounted) return;
      setState(() => _status = 'ISSUED');
      showTimedSnackBar(context, message: 'ออกใบกำกับภาษีและตัดสต๊อกสำเร็จ');
    } catch (e) {
      if (mounted) _error('ออกใบกำกับภาษีไม่ได้', e);
    }
  }

  Future<void> _voidDocument() async {
    if (_id == null) return;
    try {
      await _api.voidDocument(_id!);
      if (!mounted) return;
      setState(() => _status = 'VOID');
      showTimedSnackBar(context, message: 'ยกเลิกใบกำกับภาษีและคืนสต๊อกสำเร็จ');
    } catch (e) {
      if (mounted) _error('ยกเลิกใบกำกับภาษีไม่ได้', e);
    }
  }

  void _error(String message, Object e) => showTimedSnackBar(
    context,
    message: '$message\nรายละเอียด: $e',
    error: true,
  );

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu: _activeMenu,
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(LaooLayout.cardMargin),
                      children: [
                        _caption(accent, compact),
                        const SizedBox(height: 8),
                        _documentCard(accent, compact),
                        const SizedBox(height: 8),
                        _detailCard(accent, compact),
                        const SizedBox(height: 8),
                        _summaryCard(accent, compact),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _surface(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  Widget _caption(Color accent, bool compact) => _surface(
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        WorkspacePageTitle(
          title: '$_menuName > ${_id == null ? 'เพิ่ม' : 'แก้ไข'}',
          favoriteKey: _activeMenu,
          titleColor: Colors.black,
        ),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            if (_status == 'DRAFT' && _id != null && _actions['edit'] == true)
              FilledButton.icon(
                onPressed: _issue,
                style: _filledStyle(accent),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('ออกใบกำกับภาษี'),
              ),
            if (_status == 'ISSUED' && _actions['edit'] == true)
              OutlinedButton.icon(
                onPressed: _voidDocument,
                style: _outlinedStyle(accent),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('ยกเลิกเอกสาร'),
              ),
            OutlinedButton.icon(
              onPressed: () => context.go('/company/tax-invoices'),
              style: _outlinedStyle(accent),
              icon: const Icon(Icons.close),
              label: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed:
                  _editable &&
                      !_saving &&
                      (_id == null
                          ? _actions['create'] == true
                          : _actions['edit'] == true)
                  ? _save
                  : null,
              style: _filledStyle(accent),
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _documentCard(Color accent, bool compact) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.receipt_long_outlined, 'ข้อมูลเอกสาร', accent),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            SizedBox(
              width: compact ? double.infinity : 210,
              child: DropdownButtonFormField<String>(
                initialValue: _referenceType,
                decoration: const InputDecoration(labelText: 'อ้างอิงเอกสาร'),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('ไม่อ้างอิง')),
                  DropdownMenuItem(
                    value: 'QUOTATION',
                    child: Text('ใบเสนอราคา'),
                  ),
                  DropdownMenuItem(
                    value: 'PREORDER',
                    child: Text('ใบรับจองสินค้า'),
                  ),
                  DropdownMenuItem(
                    value: 'TEMP_RECEIPT',
                    child: Text('ใบเสร็จรับเงินชั่วคราว'),
                  ),
                ],
                onChanged: !_editable
                    ? null
                    : (v) => setState(() {
                        _referenceType = v ?? 'NONE';
                        _referenceId = null;
                      }),
              ),
            ),
            if (_referenceType != 'NONE')
              SizedBox(
                width: compact ? double.infinity : 310,
                child: DropdownButtonFormField<int>(
                  key: ValueKey(_referenceType),
                  initialValue: _referenceId,
                  decoration: const InputDecoration(labelText: '* เลือกเอกสาร'),
                  items: _references
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text('${e['code']} | ${e['customerName']}'),
                        ),
                      )
                      .toList(),
                  onChanged: !_editable
                      ? null
                      : (v) {
                          setState(() => _referenceId = v);
                          if (v != null) _loadSource(v);
                        },
                ),
              ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: TextFormField(
                initialValue: _code.isEmpty ? 'สร้างอัตโนมัติ' : _code,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'เลขที่เอกสาร'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 190,
              child: InkWell(
                onTap: !_editable ? null : _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '* วันที่เอกสาร',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(_formatDate(_date)),
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 360,
              child: DropdownButtonFormField<int>(
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: '* ลูกค้า'),
                items: _customers
                    .map(
                      (e) => DropdownMenuItem<int>(
                        value: (e['customerId'] as num).toInt(),
                        child: Text(
                          '${e['customerCode']} | ${e['customerName']}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: !_editable || _referenceType != 'NONE'
                    ? null
                    : _customerChanged,
                validator: (v) => v == null ? 'กรุณาเลือกลูกค้า' : null,
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 360,
              child: TextFormField(
                initialValue: '${_customer?['address'] ?? ''}',
                readOnly: true,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ที่อยู่ลูกค้า'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 210,
              child: TextFormField(
                initialValue: '${_customer?['taxId'] ?? ''}',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'เลขประจำตัวผู้เสียภาษี',
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 230,
              child: TextFormField(
                controller: _contactName,
                readOnly: !_editable,
                decoration: const InputDecoration(labelText: 'ชื่อผู้ติดต่อ'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 190,
              child: TextFormField(
                controller: _contactPhone,
                readOnly: !_editable,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรผู้ติดต่อ',
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 230,
              child: TextFormField(
                controller: _contactEmail,
                readOnly: !_editable,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 200,
              child: TextFormField(
                controller: _paymentType,
                readOnly: !_editable,
                decoration: const InputDecoration(labelText: 'ประเภทชำระเงิน'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 160,
              child: _numberField(
                _creditDays,
                'จำนวนวันเครดิต',
                readOnly: !_editable,
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'วันครบกำหนด'),
                child: Text(
                  _formatDate(
                    _date.add(Duration(days: _int(_creditDays.text))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _detailCard(Color accent, bool compact) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                Icons.inventory_2_outlined,
                'รายการสินค้า',
                accent,
              ),
            ),
            if (_editable)
              FilledButton.icon(
                onPressed: () => _editLine(),
                style: _filledStyle(accent),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรายการ'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_lines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('ยังไม่มีรายการสินค้า')),
          )
        else if (compact)
          ..._lines.indexed.map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              color: LaooColors.background,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.$2['itemCode']} | ${e.$2['itemName']}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'จำนวน ${_money(e.$2['quantity'])} ${e.$2['unitName'] ?? e.$2['unitCode'] ?? ''} | ราคา ${_money(e.$2['unitPrice'])} | รวม ${_money(_lineAmount(e.$2))}',
                          ),
                        ],
                      ),
                    ),
                    if (_editable)
                      IconButton(
                        onPressed: () => _editLine(index: e.$1),
                        icon: Icon(Icons.edit_outlined, color: accent),
                      ),
                    if (_editable)
                      IconButton(
                        onPressed: () => _removeLine(e.$1),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: LaooColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                accent.withValues(alpha: .10),
              ),
              dividerThickness: .5,
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('รหัสสินค้า')),
                DataColumn(label: Text('ชื่อสินค้า')),
                DataColumn(label: Text('จำนวน'), numeric: true),
                DataColumn(label: Text('หน่วยนับ')),
                DataColumn(label: Text('ราคา'), numeric: true),
                DataColumn(label: Text('ส่วนลด'), numeric: true),
                DataColumn(label: Text('รวมเงิน'), numeric: true),
              ],
              rows: _lines.indexed
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(Text('${e.$1 + 1}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_editable)
                                IconButton(
                                  onPressed: () => _editLine(index: e.$1),
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: accent,
                                  ),
                                ),
                              if (_editable)
                                IconButton(
                                  onPressed: () => _removeLine(e.$1),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: LaooColors.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(Text('${e.$2['itemCode']}')),
                        DataCell(Text('${e.$2['itemName']}')),
                        DataCell(Text(_money(e.$2['quantity']))),
                        DataCell(
                          Text('${e.$2['unitName'] ?? e.$2['unitCode'] ?? ''}'),
                        ),
                        DataCell(Text(_money(e.$2['unitPrice']))),
                        DataCell(Text(_money(_lineDiscount(e.$2)))),
                        DataCell(Text(_money(_lineAmount(e.$2)))),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    ),
  );

  Widget _summaryCard(Color accent, bool compact) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.calculate_outlined, 'สรุปยอดเงิน', accent),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            SizedBox(
              width: compact ? double.infinity : 170,
              child: _numberField(
                _discountPercent,
                'ส่วนลดท้ายเอกสาร %',
                readOnly: !_editable,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 190,
              child: _numberField(
                _discountAmount,
                'ส่วนลดจำนวนเงิน',
                readOnly: !_editable,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 150,
              child: _numberField(
                _taxPercent,
                'ภาษี %',
                readOnly: !_editable,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 420,
              child: TextFormField(
                controller: _remark,
                readOnly: !_editable,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: compact ? double.infinity : 390,
            child: Column(
              children: [
                _summaryRow('รวมเงิน', _subtotal),
                _summaryRow('ส่วนลด', _headerDiscount),
                _summaryRow('รวมหลังหักส่วนลด', _afterDiscount),
                _summaryRow(
                  'ภาษี ${_number(_taxPercent.text).toStringAsFixed(2)}%',
                  _taxAmount,
                ),
                const Divider(),
                _summaryRow(
                  'รวมเงินสุทธิ',
                  _netAmount,
                  bold: true,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(IconData icon, String text, Color accent) => Row(
    children: [
      Icon(icon, color: accent),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          color: LaooColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
  Widget _summaryRow(
    String label,
    double value, {
    bool bold = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : null),
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w700 : null,
          ),
        ),
      ],
    ),
  );
  ButtonStyle _filledStyle(Color accent) => FilledButton.styleFrom(
    backgroundColor: accent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
  ButtonStyle _outlinedStyle(Color accent) => OutlinedButton.styleFrom(
    foregroundColor: accent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: workspaceThemeController.value.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (value != null) setState(() => _date = value);
  }

  static Widget _numberField(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) => TextFormField(
    controller: controller,
    readOnly: readOnly,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
    ],
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
  );
  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : [];
  static double _number(String value) =>
      double.tryParse(value.replaceAll(',', '')) ?? 0;
  static int _int(String value) => int.tryParse(value) ?? 0;
  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  static String _money(dynamic value) =>
      (value is num ? value : num.tryParse('$value') ?? 0)
          .toStringAsFixed(2)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  static double _lineBefore(Map<String, dynamic> line) =>
      _number('${line['quantity']}') * _number('${line['unitPrice']}');
  static double _lineDiscount(Map<String, dynamic> line) =>
      '${line['discountType'] ?? 'N'}' == 'P'
      ? _lineBefore(line) * _number('${line['discountPercent']}') / 100
      : '${line['discountType'] ?? 'N'}' == 'A'
      ? _number('${line['discountAmount']}')
      : 0;
  static double _lineAmount(Map<String, dynamic> line) =>
      math.max(0, _lineBefore(line) - _lineDiscount(line));
}
