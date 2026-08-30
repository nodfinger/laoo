import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../../delivery_note/services/delivery_note_receipt_pdf_service.dart';
import '../data/temporary_receipt_api.dart';
import 'temporary_receipt_action_page.dart';

Future<({bool proceed, Uint8List? bytes})> _askTemporaryReceiptSignature(
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

class TemporaryReceiptPage extends StatelessWidget {
  const TemporaryReceiptPage({this.action = false, this.receiptId, super.key});

  final bool action;
  final int? receiptId;

  @override
  Widget build(BuildContext context) => action
      ? TemporaryReceiptActionPage(receiptId: receiptId)
      : const TemporaryReceiptListPage();
}

class TemporaryReceiptListPage extends StatefulWidget {
  const TemporaryReceiptListPage({super.key});

  @override
  State<TemporaryReceiptListPage> createState() =>
      _TemporaryReceiptListPageState();
}

class _TemporaryReceiptListPageState extends State<TemporaryReceiptListPage> {
  static const _activeMenu = 'companyTemporaryReceipts';
  final _api = TemporaryReceiptApi();
  final _profile = UserProfileRepository();
  final _search = TextEditingController();

  List<Map<String, dynamic>> _rows = const [];
  Map<String, bool> _actions = const {};
  String _menuName = 'ใบเสร็จรับเงินชั่วคราว';
  String _status = 'ALL';
  String _referenceType = 'ALL';
  bool _loading = true;
  bool _card = false;
  int _page = 0;

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  int get _pageCount => math.max(1, (_rows.length / _pageSize).ceil());
  List<Map<String, dynamic>> get _visibleRows => _rows
      .skip(_page.clamp(0, _pageCount - 1) * _pageSize)
      .take(_pageSize)
      .toList();

  @override
  void initState() {
    super.initState();
    _resolveMenuName();
    _loadViewMode();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _resolveMenuName() async {
    try {
      final value = await NavigationMenuRepository().resolveMenuName(
        routeName: _activeMenu,
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
        setState(() {
          _card =
              profile['defaultViewMode']?.toString().toUpperCase() == 'CARD';
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.list(
          search: _search.text,
          status: _status,
          referenceType: _referenceType,
        ),
        _api.actions(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = values[0] as List<Map<String, dynamic>>;
        _actions = values[1] as Map<String, bool>;
        _page = _page.clamp(0, _pageCount - 1);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error('ไม่สามารถโหลดรายการใบเสร็จรับเงินชั่วคราวได้', error);
    }
  }

  void _error(String message, Object error) {
    showTimedSnackBar(
      context,
      message: '$message\nรายละเอียด: $error',
      error: true,
    );
  }

  Future<void> _printRow(Map<String, dynamic> row) async {
    final signature = await _askTemporaryReceiptSignature(context);
    if (!signature.proceed) return;
    try {
      final id = (row['temporaryReceiptId'] as num).toInt();
      final data = await _api.get(id);
      final header = Map<String, dynamic>.from(
        data['header'] as Map? ?? const {},
      );
      final payments = List<Map<String, dynamic>>.from(
        data['payments'] as List? ?? const [],
      );
      final setup =
          companySetupController.current ?? await companySetupController.load();
      final noReference =
          header['quotationId'] == null && header['preOrderId'] == null;
      final items = payments
          .map(
            (payment) => <String, dynamic>{
              'itemName': noReference &&
                      '${header['remark'] ?? ''}'.trim().isNotEmpty
                  ? '${header['remark']}'.trim()
                  : payment['paymentMethodName'] ??
                      payment['paymentMethodCode'] ??
                      'รับเงิน',
              'deliveryQty': 1,
              'unitPrice': payment['amount'] ?? 0,
              'unitName': payment['referenceNo'] ?? '',
            },
          )
          .toList();
      await DeliveryNoteReceiptPdfService.export(
        documentCode: '${header['receiptCode'] ?? row['receiptCode'] ?? ''}',
        documentDate:
            DateTime.tryParse('${header['receiptDate'] ?? row['receiptDate']}') ??
            DateTime.now(),
        companyName: DeliveryNoteReceiptPdfService.defaultCompanyName,
        companyAddress: DeliveryNoteReceiptPdfService.defaultCompanyAddress,
        companyPhone: setup.telephone ?? '',
        companyEmail: setup.email ?? '',
        companyTaxId: DeliveryNoteReceiptPdfService.defaultCompanyTaxId,
        customerCode: '',
        customerName: '${header['customerName'] ?? row['customerName'] ?? ''}',
        customerAddress: '${header['address'] ?? ''}',
        contactName: '${header['contactName'] ?? ''}',
        contactPhone: '${header['contactPhone'] ?? ''}',
        issuerName: 'โชคชัย วันดี',
        remark: '${header['remark'] ?? ''}',
        items: items,
        signatureBytes: signature.bytes,
        documentTitle: 'ใบเสร็จรับเงินชั่วคราว',
        accent: workspaceThemeController.value.primary,
      );
    } catch (error) {
      if (mounted) _error('ไม่สามารถพิมพ์ใบเสร็จรับเงินชั่วคราวได้', error);
    }
  }

  String _date(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _money(dynamic raw) {
    final value = num.tryParse('$raw') ?? 0;
    return value
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _statusName(dynamic raw) => switch (raw?.toString().toUpperCase()) {
    'DRAFT' => 'ร่าง',
    'CONFIRMED' => 'ยืนยันแล้ว',
    'VOID' => 'ยกเลิก',
    _ => raw?.toString() ?? '-',
  };

  String _referenceName(Map<String, dynamic> row) {
    final code = row['referenceCode']?.toString() ?? '';
    return switch (row['referenceType']?.toString()) {
      'QUOTATION' => 'ใบเสนอราคา $code',
      'PREORDER' => 'ใบจอง $code',
      _ => 'ไม่อ้างเอกสาร',
    };
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
  );

  Future<void> _delete(Map<String, dynamic> row) async {
    final accent = workspaceThemeController.value.primary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Text(
              'ยืนยันการลบข้อมูล',
              style: TextStyle(
                color: LaooColors.error,
                fontSize: LaooTypography.workspaceCaption,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ต้องการลบ ${row['receiptCode']} - ${row['customerName']} หรือไม่?',
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete((row['temporaryReceiptId'] as num).toInt());
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ลบเอกสารสำเร็จ');
      await _load();
    } catch (error) {
      if (mounted) _error('ไม่สามารถลบเอกสารได้', error);
    }
  }

  Widget _actionButtons(Map<String, dynamic> row, Color accent) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'แก้ไข',
        onPressed: _actions['edit'] == true
            ? () => context.go(
                '/company/temporary-receipts?action=edit&id=${row['temporaryReceiptId']}',
              )
            : null,
        icon: Icon(Icons.edit_outlined, color: accent),
      ),
      IconButton(
        tooltip: 'ลบ',
        onPressed: _actions['delete'] == true ? () => _delete(row) : null,
        icon: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      IconButton(
        tooltip: 'พิมพ์',
        onPressed: () => _printRow(row),
        icon: Icon(Icons.print_outlined, color: accent),
      ),
    ],
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );

  Widget _cardRow(Map<String, dynamic> row, Color accent) => _surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${row['receiptCode']} | ${row['customerName']}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
            _actionButtons(row, accent),
          ],
        ),
        const SizedBox(height: 6),
        Text('${_date(row['receiptDate'])} | ${_referenceName(row)}'),
        const SizedBox(height: 6),
        Text(
          'ช่องทางรับเงิน: ${row['paymentNames']?.toString().isNotEmpty == true ? row['paymentNames'] : '-'}',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'รับเงิน ${_money(row['receivedAmount'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _badge(
              _statusName(row['statusCode']),
              row['statusCode'] == 'VOID' ? Colors.red : accent,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _table(Color accent, double width) {
    return _surface(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: width,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            accent.withValues(alpha: .09),
          ),
          dividerThickness: .5,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('เลขที่เอกสาร')),
            DataColumn(label: Text('วันที่')),
            DataColumn(label: Text('ลูกค้า')),
            DataColumn(label: Text('อ้างอิง')),
            DataColumn(label: Text('ช่องทางรับเงิน')),
            DataColumn(label: Text('รับเงิน'), numeric: true),
            DataColumn(label: Text('สถานะ')),
          ],
          rows: _visibleRows.indexed.map((entry) {
            final row = entry.$2;
            return DataRow(
              cells: [
                DataCell(Text('${_page * _pageSize + entry.$1 + 1}')),
                DataCell(_actionButtons(row, accent)),
                DataCell(Text('${row['receiptCode']}')),
                DataCell(Text(_date(row['receiptDate']))),
                DataCell(
                  Text('${row['customerCode']} | ${row['customerName']}'),
                ),
                DataCell(Text(_referenceName(row))),
                DataCell(Text('${row['paymentNames'] ?? '-'}')),
                DataCell(Text(_money(row['receivedAmount']))),
                DataCell(
                  _badge(
                    _statusName(row['statusCode']),
                    row['statusCode'] == 'VOID' ? Colors.red : accent,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _pagination(Color accent) {
    final start = _rows.isEmpty ? 0 : _page * _pageSize + 1;
    final end = math.min((_page + 1) * _pageSize, _rows.length);
    return _surface(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: LaooLayout.paginationCardHeight,
        child: Row(
          children: [
            InkWell(
              onTap: _page > 0 ? () => setState(() => _page--) : null,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chevron_left, color: Colors.grey),
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
              child: Text(
                '${_page + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _page + 1 < _pageCount
                  ? () => setState(() => _page++)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Text('$start-$end จาก ${_rows.length}'),
          ],
        ),
      ),
    );
  }

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
                  final cardMode = compact || _card;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _surface(
                        child: Row(
                          children: [
                            Expanded(
                              child: WorkspacePageTitle(
                                title: _menuName,
                                favoriteKey: _activeMenu,
                                titleColor: LaooColors.textPrimary,
                              ),
                            ),
                            if (!compact) ...[
                              IconButton(
                                tooltip: cardMode
                                    ? 'แสดงแบบรายการ'
                                    : 'แสดงแบบการ์ด',
                                onPressed: () => setState(() => _card = !_card),
                                style: IconButton.styleFrom(
                                  foregroundColor: accent,
                                  backgroundColor: accent.withValues(
                                    alpha: .10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
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
                                  ? () => context.go(
                                      '/company/temporary-receipts?action=new',
                                    )
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
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
                              width: compact ? constraints.maxWidth : 360,
                              child: TextField(
                                controller: _search,
                                onSubmitted: (_) => _load(),
                                decoration: const InputDecoration(
                                  labelText:
                                      'ค้นหาเลขที่เอกสาร/ลูกค้า/เอกสารอ้างอิง',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: compact ? constraints.maxWidth : 220,
                              child: DropdownButtonFormField<String>(
                                initialValue: _referenceType,
                                decoration: const InputDecoration(
                                  labelText: 'อ้างอิง',
                                ),
                                style: const TextStyle(
                                  color: LaooColors.textPrimary,
                                  fontSize: LaooTypography.comboBox,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'ALL',
                                    child: Text('ทั้งหมด'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'NONE',
                                    child: Text('ไม่อ้างเอกสาร'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'QUOTATION',
                                    child: Text('ใบเสนอราคา'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PREORDER',
                                    child: Text('ใบจองสินค้า'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _referenceType = value ?? 'ALL',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: compact ? constraints.maxWidth : 200,
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: 'สถานะ',
                                ),
                                style: const TextStyle(
                                  color: LaooColors.textPrimary,
                                  fontSize: LaooTypography.comboBox,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'ALL',
                                    child: Text('ทั้งหมด'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DRAFT',
                                    child: Text('ร่าง'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'CONFIRMED',
                                    child: Text('ยืนยันแล้ว'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'VOID',
                                    child: Text('ยกเลิก'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _status = value ?? 'ALL'),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _load,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              icon: const Icon(Icons.search),
                              label: const Text('ค้นหา'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_rows.isEmpty)
                        _surface(
                          child: const SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                'ยังไม่มีรายการใบเสร็จรับเงินชั่วคราว',
                              ),
                            ),
                          ),
                        )
                      else if (cardMode)
                        ..._visibleRows.expand(
                          (row) => [
                            _cardRow(row, accent),
                            const SizedBox(height: 8),
                          ],
                        )
                      else
                        _table(accent, constraints.maxWidth),
                      const SizedBox(height: 8),
                      _pagination(accent),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
