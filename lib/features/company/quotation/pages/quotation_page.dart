import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/quotation_api.dart';
import '../services/quotation_pdf_service.dart';
import 'quotation_document_action_page.dart';

Future<({bool proceed, Uint8List? bytes})> _askQuotationSignature(
  BuildContext context,
) async {
  final attach = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('แนบลายเซ็นต์'),
      content: const Text('ต้องการแนบลายเซ็นต์ในเอกสารหรือไม่?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ไม่แนบ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('แนบลายเซ็นต์'),
        ),
      ],
    ),
  );
  if (attach == null) return (proceed: false, bytes: null);
  if (!attach) return (proceed: true, bytes: null);
  final data = await rootBundle.load(
    'assets/images/signature_chokchai_wandee.png',
  );
  return (
    proceed: true,
    bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

class QuotationPage extends StatelessWidget {
  const QuotationPage({this.action = false, this.quotationId, super.key});
  final bool action;
  final int? quotationId;

  @override
  Widget build(BuildContext context) => action
      ? QuotationDocumentActionPage(quotationId: quotationId)
      : const QuotationListPage();
}

class QuotationListPage extends StatefulWidget {
  const QuotationListPage({super.key});
  @override
  State<QuotationListPage> createState() => _QuotationListPageState();
}

class _QuotationListPageState extends State<QuotationListPage> {
  final _api = QuotationApi();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, bool> _actions = {};
  String _menuName = '';
  bool _loading = true, _card = false;
  int? _printingId;

  @override
  void initState() {
    super.initState();
    _resolveMenuName();
    _load();
  }

  Future<void> _resolveMenuName() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: 'companyQuotations',
      fallback: 'ใบเสนอราคา',
    );
    if (mounted) setState(() => _menuName = name);
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _rows = await _api.list();
      _actions = await _api.actions();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'โหลดรายการใบเสนอราคาไม่สำเร็จ\nรายละเอียด: $e',
          error: true,
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _date(dynamic value) =>
      value == null ? '' : value.toString().split('T').first;

  String _money(dynamic value) {
    final amount = num.tryParse(value?.toString() ?? '') ?? 0;
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  Future<void> _printRow(Map<String, dynamic> row) async {
    final signature = await _askQuotationSignature(context);
    if (!signature.proceed) return;
    final quotationId = (row['quotationId'] as num).toInt();
    setState(() => _printingId = quotationId);
    try {
      final values = await Future.wait([_api.get(quotationId), _api.lookup()]);
      final data = Map<String, dynamic>.from(values[0]);
      final lookup = Map<String, dynamic>.from(values[1]);
      final header = Map<String, dynamic>.from(
        data['header'] as Map? ?? const {},
      );
      final details = List<Map<String, dynamic>>.from(
        data['items'] as List? ?? const [],
      );
      final customers = List<Map<String, dynamic>>.from(
        lookup['customers'] as List? ?? const [],
      );
      final employees = List<Map<String, dynamic>>.from(
        lookup['employees'] as List? ?? const [],
      );
      final items = List<Map<String, dynamic>>.from(
        lookup['items'] as List? ?? const [],
      );
      final creditTypes = List<Map<String, dynamic>>.from(
        lookup['creditTypes'] as List? ?? const [],
      );
      final customerId = (header['customerId'] as num?)?.toInt();
      final customer = customers
          .where(
            (value) => (value['customerId'] as num?)?.toInt() == customerId,
          )
          .firstOrNull;
      final employeeId = (header['salespersonEmployeeId'] as num?)?.toInt();
      final employee = employees
          .where(
            (value) => (value['employeeId'] as num?)?.toInt() == employeeId,
          )
          .firstOrNull;
      final paymentType = '${header['paymentType'] ?? ''}';
      final creditType = creditTypes
          .where((value) => '${value['code'] ?? ''}' == paymentType)
          .firstOrNull;
      final contactName = '${header['contactName'] ?? ''}';
      final contactIsSecond =
          contactName.isNotEmpty &&
          contactName == '${customer?['contactName2'] ?? ''}';
      final sessionName = appAuthController.session?.displayName?.trim();
      final salespersonName = '${employee?['fullName'] ?? ''}'.trim().isNotEmpty
          ? '${employee?['fullName']}'
          : (sessionName?.isNotEmpty == true ? sessionName! : '-');
      final exportItems = details.map((detail) {
        final itemId = (detail['itemId'] as num?)?.toInt();
        final lookupItem = items
            .where((value) => (value['itemId'] as num?)?.toInt() == itemId)
            .firstOrNull;
        return <String, dynamic>{
          ...detail,
          'unitName': lookupItem?['unitCode'] ?? detail['unitCode'],
        };
      }).toList();
      final setup =
          companySetupController.current ?? await companySetupController.load();

      await QuotationPdfService.export(
        documentCode: '${header['quoteCode'] ?? row['quoteCode'] ?? ''}',
        documentDate:
            DateTime.tryParse('${header['quoteDate'] ?? row['quoteDate']}') ??
            DateTime.now(),
        companyPhone: setup.telephone ?? '',
        companyEmail: setup.email ?? '',
        customerCode: '${customer?['cusCode'] ?? ''}',
        customerName: '${customer?['cusName'] ?? row['customerName'] ?? ''}',
        customerAddress: '${customer?['address'] ?? ''}',
        customerTaxId: '${customer?['taxId'] ?? ''}',
        contactName: contactName,
        contactPhone:
            '${customer?[contactIsSecond ? 'contactPhone2' : 'contactPhone1'] ?? ''}',
        contactEmail:
            '${customer?[contactIsSecond ? 'contactEmail2' : 'contactEmail1'] ?? customer?['email'] ?? ''}',
        salespersonName: salespersonName,
        validDays: (header['validDays'] as num?)?.toInt() ?? 0,
        paymentType: '${creditType?['name'] ?? paymentType}',
        creditDays: (header['creditDays'] as num?)?.toInt() ?? 0,
        remark: '${header['remark'] ?? ''}',
        items: exportItems,
        discountPercent:
            double.tryParse('${header['discountPercent'] ?? 0}') ?? 0,
        vatPercent:
            double.tryParse(
              '${header['taxPercent'] ?? header['vatPercent'] ?? 0}',
            ) ??
            0,
        signatureBytes: signature.bytes,
        accent: workspaceThemeController.value.primary,
      );
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถพิมพ์ใบเสนอราคาได้\nรายละเอียด: $error\nกรุณาตรวจสอบข้อมูลเอกสารแล้วลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _printingId = null);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Text('ยืนยันการลบข้อมูล'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              color: workspaceThemeController.value.primary.withValues(
                alpha: .10,
              ),
              child: Text('${row['quoteCode']} | ${row['customerName']}'),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'ยกเลิก',
              style: TextStyle(color: workspaceThemeController.value.primary),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.delete((row['quotationId'] as num).toInt());
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ลบใบเสนอราคา ${row['quoteCode']} สำเร็จ',
        );
        setState(() => _loading = true);
        await _load();
      }
    } catch (e) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: 'ลบใบเสนอราคาไม่สำเร็จ\nรายละเอียด: $e',
          error: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final query = _search.text.trim().toLowerCase();
    final rows = _rows
        .where(
          (e) =>
              query.isEmpty ||
              '${e['quoteCode']} ${e['customerName']}'.toLowerCase().contains(
                query,
              ),
        )
        .toList();
    return SupportWorkspaceShell(
      pageTitle: 'ใบเสนอราคา',
      activeMenu: 'companyQuotations',
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final card = _card || constraints.maxWidth < 900;
                  return ListView(
                    padding: const EdgeInsets.all(LaooLayout.cardMargin),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(LaooLayout.cardPadding),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _menuName,
                                          style: TextStyle(
                                            color: LaooColors.textPrimary,
                                            fontSize: LaooTypography.pageTitle,
                                            fontWeight:
                                                LaooTypography.pageTitleWeight,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.star_outline, color: accent),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      foregroundColor: accent,
                                      backgroundColor: accent.withValues(
                                        alpha: .10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    onPressed: () =>
                                        setState(() => _card = !_card),
                                    icon: Icon(
                                      card
                                          ? Icons.view_list_outlined
                                          : Icons.grid_view_outlined,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  FilledButton.icon(
                                    onPressed: _actions['create'] == false
                                        ? null
                                        : () => context.go(
                                            '/company/quotations?action=new',
                                          ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('เพิ่มเอกสาร'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(LaooLayout.cardPadding),
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'ค้นหาเลขที่เอกสาร/ชื่อลูกค้า',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      card
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final e = rows[index];
                                return Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    side: BorderSide.none,
                                  ),
                                  child: ListTile(
                                    onTap: _actions['edit'] == true
                                        ? () => context.go(
                                            '/company/quotations?action=edit&id=${e['quotationId']}',
                                          )
                                        : null,
                                    title: Text(
                                      '${e['quoteCode']} | ${e['customerName']}',
                                    ),
                                    subtitle: Text(
                                      'วันที่ ${_date(e['quoteDate'])} | รวมเงิน ${_money(e['totalAmount'])}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'พิมพ์ใบเสนอราคา',
                                          onPressed:
                                              _printingId ==
                                                  (e['quotationId'] as num)
                                                      .toInt()
                                              ? null
                                              : () => _printRow(e),
                                          icon:
                                              _printingId ==
                                                  (e['quotationId'] as num)
                                                      .toInt()
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.print_outlined,
                                                  color: accent,
                                                ),
                                        ),
                                        Text('${e['statusCode']}'),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : _table(rows, accent),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LaooLayout.cardPadding,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              const SizedBox.shrink(),
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '1',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    rows.isEmpty
                                        ? '0-0 จาก 0'
                                        : '1-${rows.length} จาก ${rows.length}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _table(List<Map<String, dynamic>> rows, Color accent) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide.none,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(accent.withValues(alpha: .10)),
        headingTextStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('เลขที่เอกสาร')),
          DataColumn(label: Text('วันที่เอกสาร')),
          DataColumn(label: Text('ชื่อลูกค้า')),
          DataColumn(label: Text('รวมเงิน')),
        ],
        rows: rows
            .map(
              (e) => DataRow(
                cells: [
                  DataCell(Text('${e['quotationId']}')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: _actions['edit'] == true
                              ? 'แก้ไข'
                              : 'ไม่มีสิทธิ์แก้ไข',
                          onPressed: _actions['edit'] == true
                              ? () => context.go(
                                  '/company/quotations?action=edit&id=${e['quotationId']}',
                                )
                              : null,
                          icon: Icon(
                            _actions['edit'] == true
                                ? Icons.edit_outlined
                                : Icons.lock_outline,
                            color: accent,
                          ),
                        ),
                        IconButton(
                          tooltip: _actions['delete'] == true
                              ? 'ลบ'
                              : 'ไม่มีสิทธิ์ลบ',
                          onPressed: _actions['delete'] == true
                              ? () => _delete(e)
                              : null,
                          icon: Icon(
                            _actions['delete'] == true
                                ? Icons.delete_outline
                                : Icons.lock_outline,
                            color: _actions['delete'] == true
                                ? Colors.red
                                : accent,
                          ),
                        ),
                        IconButton(
                          tooltip: 'พิมพ์ใบเสนอราคา',
                          onPressed:
                              _printingId == (e['quotationId'] as num).toInt()
                              ? null
                              : () => _printRow(e),
                          icon: _printingId == (e['quotationId'] as num).toInt()
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.print_outlined, color: accent),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text('${e['quoteCode']}')),
                  DataCell(Text(_date(e['quoteDate']))),
                  DataCell(Text('${e['customerName']}')),
                  DataCell(Text(_money(e['totalAmount']))),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class QuotationActionPage extends StatefulWidget {
  const QuotationActionPage({super.key});
  @override
  State<QuotationActionPage> createState() => _QuotationActionPageState();
}

class _QuotationActionPageState extends State<QuotationActionPage> {
  final _api = QuotationApi();
  final _vat = TextEditingController(text: '7');
  final _remark = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController(text: '0');
  bool _loading = true, _saving = false;
  String _menuName = '';
  List<Map<String, dynamic>> _customers = [], _employees = [], _items = [];
  int? _customerId, _employeeId, _itemId;

  @override
  void initState() {
    super.initState();
    _resolveMenuName();
    _load();
  }

  Future<void> _resolveMenuName() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: 'companyQuotations',
      fallback: 'ใบเสนอราคา',
    );
    if (mounted) setState(() => _menuName = name);
  }

  @override
  void dispose() {
    _api.dispose();
    _vat.dispose();
    _remark.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.lookup();
      _customers = List<Map<String, dynamic>>.from(
        data['customers'] ?? const [],
      );
      _employees = List<Map<String, dynamic>>.from(
        data['employees'] ?? const [],
      );
      _items = List<Map<String, dynamic>>.from(data['items'] ?? const []);
      final current = _employees.where((e) => e['isCurrent'] == true).toList();
      if (current.isNotEmpty) {
        _employeeId = (current.first['employeeId'] as num).toInt();
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'โหลดข้อมูลใบเสนอราคาไม่สำเร็จ\nรายละเอียด: $e',
          error: true,
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_customerId == null || _employeeId == null || _itemId == null) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกลูกค้า ผู้เสนอราคา และสินค้า',
        error: true,
      );
      return;
    }
    final qty = double.tryParse(_quantity.text.trim()),
        price = double.tryParse(_price.text.trim()),
        vat = double.tryParse(_vat.text.trim());
    if (qty == null ||
        qty <= 0 ||
        price == null ||
        price < 0 ||
        vat == null ||
        vat < 0 ||
        vat > 100) {
      showTimedSnackBar(
        context,
        message: 'กรุณาตรวจสอบจำนวน ราคา และ VAT',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _api.create({
        'customerId': _customerId,
        'salespersonEmployeeId': _employeeId,
        'vatPercent': vat,
        'remark': _remark.text.trim(),
        'items': [
          {
            'itemId': _itemId,
            'quantity': qty,
            'unitPrice': price,
            'discountPercent': 0,
          },
        ],
      });
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกใบเสนอราคา ${result['quoteCode']} สำเร็จ',
        );
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกใบเสนอราคาไม่สำเร็จ\nรายละเอียด: $e',
          error: true,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: workspaceThemeController.value.primary),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: 'ใบเสนอราคา',
      activeMenu: 'companyQuotations',
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    WorkspacePageTitle(
                                      title: '',
                                      favoriteKey: 'companyQuotations',
                                      titleColor: Colors.transparent,
                                      titleFontSize: 1,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$_menuName > เพิ่ม',
                                      style: const TextStyle(
                                        color: LaooColors.textPrimary,
                                        fontSize: LaooTypography.pageTitle,
                                        fontWeight:
                                            LaooTypography.pageTitleWeight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                              context.go('/company/quotations'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('ยกเลิก'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _saving ? null : _save,
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('บันทึก'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (false)
                            Text(
                              'ข้อมูลหัวเอกสาร',
                              style: TextStyle(
                                color: LaooColors.textPrimary,
                                fontSize: LaooTypography.sectionTitle,
                                fontWeight: LaooTypography.emphasizedWeight,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (false)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'สถานะ',
                                  style: TextStyle(
                                    fontSize: LaooTypography.inputLabel,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(value: true, onChanged: null),
                              ],
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _customerId,
                            decoration: _dec('ลูกค้า *'),
                            items: _customers
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: (e['customerId'] as num).toInt(),
                                    child: Text(
                                      '${e['cusCode']} - ${e['cusName']}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _customerId = v),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 24,
                              runSpacing: 8,
                              children: [
                                _infoText(
                                  '\u0e40\u0e25\u0e02\u0e17\u0e35\u0e48',
                                  '\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34',
                                ),
                                _infoText(
                                  '\u0e27\u0e31\u0e19\u0e17\u0e35\u0e48',
                                  '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _employeeId,
                            decoration: _dec('ผู้เสนอราคา *'),
                            items: _employees
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: (e['employeeId'] as num).toInt(),
                                    child: Text(
                                      '${e['fullName']}${e['nickName'] == null ? '' : ' | ${e['nickName']}'}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _employeeId = v),
                          ),
                          const SizedBox(height: 12),
                          if (false)
                            TextField(
                              controller: _remark,
                              maxLines: 2,
                              decoration: _dec('หมายเหตุ'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รายการสินค้า',
                            style: TextStyle(
                              color: LaooColors.textPrimary,
                              fontSize: LaooTypography.sectionTitle,
                              fontWeight: LaooTypography.emphasizedWeight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _itemId,
                            decoration: _dec('สินค้า *'),
                            items: _items
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: (e['itemId'] as num).toInt(),
                                    child: Text(
                                      '${e['itemCode']} - ${e['itemName']}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _itemId = v;
                                final row = _items.firstWhere(
                                  (e) => (e['itemId'] as num).toInt() == v,
                                  orElse: () => {},
                                );
                                _price.text = '${row['unitPrice'] ?? 0}';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _vat,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec('VAT (%)'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _quantity,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _dec('จำนวน'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _price,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _dec('ราคาต่อหน่วย'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _quotationItemsTable(accent),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _remark,
                              maxLines: 2,
                              decoration: _dec(
                                '\u0e2b\u0e21\u0e32\u0e22\u0e40\u0e2b\u0e15\u0e38',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _vat,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _dec('VAT (%)'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('คำนวณภาษีมูลค่าเพิ่มตอนบันทึกเอกสาร'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoText(String label, String value) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: LaooColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: LaooColors.textPrimary)),
      ],
    ),
  );

  Widget _quotationItemsTable(Color accent) {
    final item = _items
        .where((e) => (e['itemId'] as num?)?.toInt() == _itemId)
        .firstOrNull;
    final quantity = double.tryParse(_quantity.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final amount = quantity * price;

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            accent.withValues(alpha: .10),
          ),
          headingTextStyle: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Action')),
            DataColumn(
              label: Text(
                '\u0e23\u0e2b\u0e31\u0e2a\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32',
              ),
            ),
            DataColumn(
              label: Text(
                '\u0e0a\u0e37\u0e48\u0e2d\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32',
              ),
            ),
            DataColumn(label: Text('\u0e08\u0e33\u0e19\u0e27\u0e19')),
            DataColumn(
              label: Text('\u0e2b\u0e19\u0e48\u0e27\u0e22\u0e19\u0e31\u0e1a'),
            ),
            DataColumn(label: Text('\u0e23\u0e32\u0e04\u0e32')),
            DataColumn(
              label: Text('\u0e23\u0e27\u0e21\u0e40\u0e07\u0e34\u0e19'),
            ),
          ],
          rows: _itemId == null
              ? const []
              : [
                  DataRow(
                    cells: [
                      const DataCell(Text('1')),
                      DataCell(
                        IconButton(
                          tooltip: '\u0e25\u0e1a',
                          onPressed: () => setState(() => _itemId = null),
                          icon: Icon(Icons.delete_outline, color: accent),
                        ),
                      ),
                      DataCell(Text('${item?['itemCode'] ?? ''}')),
                      DataCell(Text('${item?['itemName'] ?? ''}')),
                      DataCell(Text('$quantity')),
                      DataCell(Text('${item?['unitCode'] ?? ''}')),
                      DataCell(Text(price.toStringAsFixed(2))),
                      DataCell(Text(amount.toStringAsFixed(2))),
                    ],
                  ),
                ],
        ),
      ),
    );
  }
}
