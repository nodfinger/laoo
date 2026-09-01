import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../app/theme/laoo_typography.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/delivery_note_api.dart';
import '../services/delivery_note_receipt_pdf_service.dart';

Future<({bool proceed, Uint8List? bytes})> _askReceiptSignature(
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

class DeliveryNotePage extends StatelessWidget {
  const DeliveryNotePage({this.action = false, this.deliveryNoteId, super.key});
  final bool action;
  final int? deliveryNoteId;

  @override
  Widget build(BuildContext context) => action
      ? DeliveryNoteActionPage(deliveryNoteId: deliveryNoteId)
      : const _DeliveryNoteListPage();
}

class _DeliveryNoteListPage extends StatefulWidget {
  const _DeliveryNoteListPage();
  @override
  State<_DeliveryNoteListPage> createState() => _DeliveryNoteListPageState();
}

class _DeliveryNoteListPageState extends State<_DeliveryNoteListPage> {
  static const _activeMenu = 'companyDeliveryNotes';
  final _api = DeliveryNoteApi();
  final _profile = UserProfileRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  Map<String, bool> _actions = const {};
  String _menuName = 'ใบส่งของ';
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
        fallback: 'ใบส่งของ',
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  Future<void> _defaultView() async {
    try {
      final p = await _profile.get();
      if (mounted) {
        setState(
          () => _card = '${p['defaultViewMode']}'.toUpperCase() == 'CARD',
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
        _rows = values[0] as List<Map<String, dynamic>>;
        _actions = values[1] as Map<String, bool>;
        _page = _page.clamp(0, _pages - 1);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _error('โหลดรายการใบส่งของไม่ได้', e);
      }
    }
  }

  void _error(String message, Object e) => showTimedSnackBar(
    context,
    message: '$message\nรายละเอียด: $e',
    error: true,
  );
  Future<void> _printRow(Map<String, dynamic> row) async {
    final signature = await _askReceiptSignature(context);
    if (!signature.proceed) return;
    try {
      final id = (row['deliveryNoteId'] as num).toInt();
      final data = await _api.get(id);
      final header = Map<String, dynamic>.from(
        data['header'] as Map? ?? const {},
      );
      final items = List<Map<String, dynamic>>.from(
        data['items'] as List? ?? const [],
      );
      final setup =
          companySetupController.current ?? await companySetupController.load();
      final issuer = appAuthController.session?.displayName?.trim();
      final username = appAuthController.session?.username?.trim();
      final exportItems = items
          .map(
            (item) => <String, dynamic>{
              ...item,
              'unitName': item['unitName'] ?? item['unitCode'],
            },
          )
          .toList();

      await DeliveryNoteReceiptPdfService.export(
        documentCode: '${header['deliveryCode'] ?? row['deliveryCode'] ?? ''}',
        documentDate:
            DateTime.tryParse(
              '${header['deliveryDate'] ?? row['deliveryDate']}',
            ) ??
            DateTime.now(),
        companyName: DeliveryNoteReceiptPdfService.defaultCompanyName,
        companyAddress: DeliveryNoteReceiptPdfService.defaultCompanyAddress,
        companyPhone: setup.telephone ?? '',
        companyEmail: setup.email ?? '',
        companyTaxId: DeliveryNoteReceiptPdfService.defaultCompanyTaxId,
        customerCode: '${header['customerCode'] ?? row['customerCode'] ?? ''}',
        customerName: '${header['customerName'] ?? row['customerName'] ?? ''}',
        customerAddress:
            '${header['deliveryAddress'] ?? header['customerAddress'] ?? ''}',
        contactName: '${header['contactName'] ?? ''}',
        contactPhone: '${header['contactPhone'] ?? ''}',
        issuerName: issuer?.isNotEmpty == true
            ? issuer!
            : (username?.isNotEmpty == true ? username! : '-'),
        remark: '${header['remark'] ?? ''}',
        items: exportItems,
        signatureBytes: signature.bytes,
        accent: workspaceThemeController.value.primary,
      );
    } catch (e) {
      if (mounted) _error('ไม่สามารถพิมพ์ใบเสร็จรับเงินได้', e);
    }
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse('$v');
    return d == null
        ? '-'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _money(dynamic v) => (num.tryParse('$v') ?? 0)
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  String _statusName(dynamic v) => switch ('$v') {
    'DRAFT' => 'ร่าง',
    'CONFIRMED' => 'ยืนยันแล้ว',
    'VOID' => 'ยกเลิก',
    _ => '$v',
  };

  Widget _surface({required Widget child, double? height}) => Container(
    height: height,
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );

  Future<void> _delete(Map<String, dynamic> row) async {
    final accent = workspaceThemeController.value.primary;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ต้องการลบ ${row['deliveryCode']} - ${row['customerName']} หรือไม่?',
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('ยกเลิก', style: TextStyle(color: accent)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: LaooColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.delete((row['deliveryNoteId'] as num).toInt());
      await _load();
    } catch (e) {
      if (mounted) _error('ลบใบส่งของไม่ได้', e);
    }
  }

  Widget _actionsFor(Map<String, dynamic> row, Color accent) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'แก้ไข/เปิดดู',
        onPressed: _actions['view'] == true
            ? () => context.go(
                '/company/delivery-notes?action=edit&id=${row['deliveryNoteId']}',
              )
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
      IconButton(
        tooltip: 'พิมพ์',
        onPressed: () => _printRow(row),
        icon: Icon(Icons.print_outlined, color: accent),
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
                '${row['deliveryCode']} | ${_date(row['deliveryDate'])}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
            _actionsFor(row, accent),
          ],
        ),
        Text(
          '${row['customerCode']} | ${row['customerName']}',
          style: const TextStyle(color: LaooColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'อ้างอิง ${row['referenceCode']?.toString().isEmpty == true ? '-' : row['referenceCode']}  |  รวมเงิน ${_money(row['totalAmount'])}  |  ${_statusName(row['statusCode'])}',
        ),
      ],
    ),
  );

  Widget _table(Color accent, double width) => _surface(
    child: SizedBox(
      width: width,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(accent.withValues(alpha: .10)),
        headingTextStyle: const TextStyle(color: Colors.black),
        dataTextStyle: const TextStyle(color: Colors.black),
        dividerThickness: .5,
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('เลขที่เอกสาร')),
          DataColumn(label: Text('วันที่')),
          DataColumn(label: Text('ลูกค้า')),
          DataColumn(label: Text('อ้างอิง')),
          DataColumn(label: Text('รวมเงิน'), numeric: true),
          DataColumn(label: Text('สถานะ')),
        ],
        rows: _visible.indexed.map((e) {
          final r = e.$2;
          return DataRow(
            cells: [
              DataCell(Text('${e.$1 + 1 + (_page * _pageSize)}')),
              DataCell(_actionsFor(r, accent)),
              DataCell(Text('${r['deliveryCode']}')),
              DataCell(Text(_date(r['deliveryDate']))),
              DataCell(Text('${r['customerCode']} | ${r['customerName']}')),
              DataCell(
                Text(
                  '${r['referenceCode']?.toString().isEmpty == true ? '-' : r['referenceCode']}',
                ),
              ),
              DataCell(Text(_money(r['totalAmount']))),
              DataCell(Text(_statusName(r['statusCode']))),
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
        InkWell(
          onTap: _page + 1 < _pages ? () => setState(() => _page++) : null,
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
        Text(
          '${_rows.isEmpty ? 0 : _page * _pageSize + 1}-${math.min((_page + 1) * _pageSize, _rows.length)} จาก ${_rows.length}',
        ),
      ],
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
        color: const Color(0xFFF8F9FB),
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
                                titleColor: Colors.black,
                              ),
                            ),
                            if (!compact) ...[
                              IconButton(
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
                                      '/company/delivery-notes?action=new',
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
                            SizedBox(
                              width: compact ? constraints.maxWidth : 200,
                              child: DropdownButtonFormField<String>(
                                initialValue: _reference,
                                decoration: const InputDecoration(
                                  labelText: 'อ้างอิง',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'ALL',
                                    child: Text('ทั้งหมด'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'NONE',
                                    child: Text('ไม่อ้างอิง'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'QUOTATION',
                                    child: Text('ใบเสนอราคา'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PREORDER',
                                    child: Text('ใบจองสินค้า'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'TEMP_RECEIPT',
                                    child: Text('ใบเสร็จชั่วคราว'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DELIVERY_NOTE',
                                    child: Text('ใบส่งของเดิม'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _reference = v ?? 'ALL'),
                              ),
                            ),
                            SizedBox(
                              width: compact ? constraints.maxWidth : 180,
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: 'สถานะ',
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
                                onChanged: (v) =>
                                    setState(() => _status = v ?? 'ALL'),
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
                              child: Text('ยังไม่มีรายการใบส่งของ'),
                            ),
                          ),
                        )
                      else if (cardMode)
                        ..._visible.expand(
                          (r) => [
                            _cardRow(r, accent),
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

class DeliveryNoteActionPage extends StatefulWidget {
  const DeliveryNoteActionPage({this.deliveryNoteId, super.key});
  final int? deliveryNoteId;
  @override
  State<DeliveryNoteActionPage> createState() => _DeliveryNoteActionPageState();
}

class _DeliveryNoteActionPageState extends State<DeliveryNoteActionPage> {
  static const _activeMenu = 'companyDeliveryNotes';
  final _api = DeliveryNoteApi();
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _date = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _transport = TextEditingController();
  final _tracking = TextEditingController();
  final _remark = TextEditingController();
  int? _id;
  int? _customerId;
  int? _referenceId;
  String _referenceType = 'NONE';
  String _status = 'DRAFT';
  String _menuName = 'ใบส่งของ';
  bool _loading = true;
  bool _saving = false;
  bool _exportingPdf = false;
  Map<String, bool> _actions = const {};
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _lookup = const {};
  List<Map<String, dynamic>> _lines = [];

  bool get _editable =>
      _status == 'DRAFT' &&
      (_id == null ? _actions['create'] == true : _actions['edit'] == true);
  double get _total => _lines.fold(
    0,
    (s, r) => s + _num(r['deliveryQty']) * _num(r['unitPrice']),
  );
  Map<String, dynamic>? get _selectedCustomer =>
      _customers.cast<Map<String, dynamic>?>().firstWhere(
        (customer) => customer?['customerId'] == _customerId,
        orElse: () => null,
      );
  @override
  void initState() {
    super.initState();
    _id = widget.deliveryNoteId;
    final n = DateTime.now();
    _date.text =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    _resolveName();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _date,
      _contact,
      _phone,
      _address,
      _transport,
      _tracking,
      _remark,
    ]) {
      c.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  double _num(dynamic v) => double.tryParse('$v'.replaceAll(',', '')) ?? 0;
  String _money(dynamic v) => _num(v)
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  void _error(String m, Object e) =>
      showTimedSnackBar(context, message: '$m\nรายละเอียด: $e', error: true);
  Widget _surface({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  );
  Future<void> _resolveName() async {
    try {
      final n = await NavigationMenuRepository().resolveMenuName(
        routeName: _activeMenu,
        fallback: 'ใบส่งของ',
      );
      if (mounted) setState(() => _menuName = n);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([_api.lookup(), _api.actions()]);
      _lookup = Map<String, dynamic>.from(values[0]);
      _actions = values[1] as Map<String, bool>;
      _customers = List<Map<String, dynamic>>.from(
        _lookup['customers'] as List? ?? const [],
      );
      _items = List<Map<String, dynamic>>.from(
        _lookup['items'] as List? ?? const [],
      );
      if (_id != null) await _loadDoc(_id!);
    } catch (e) {
      if (mounted) _error('เปิดหน้าใบส่งของไม่ได้', e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDoc(int id) async {
    final data = await _api.get(id);
    final h = Map<String, dynamic>.from(data['header'] as Map);
    setState(() {
      _id = (h['deliveryNoteId'] as num).toInt();
      _code.text = '${h['deliveryCode'] ?? ''}';
      _date.text = '${h['deliveryDate']}'.split('T').first;
      _referenceType = '${h['referenceType'] ?? 'NONE'}';
      _referenceId = (h['referenceId'] as num?)?.toInt();
      _customerId = (h['customerId'] as num).toInt();
      _contact.text = '${h['contactName'] ?? ''}';
      _phone.text = '${h['contactPhone'] ?? ''}';
      _address.text = '${h['deliveryAddress'] ?? h['customerAddress'] ?? ''}';
      _transport.text = '${h['transportBy'] ?? ''}';
      _tracking.text = '${h['trackingNo'] ?? ''}';
      _remark.text = '${h['remark'] ?? ''}';
      _status = '${h['statusCode'] ?? 'DRAFT'}';
      _lines = List<Map<String, dynamic>>.from(
        data['items'] as List? ?? const [],
      );
    });
  }

  List<Map<String, dynamic>> _refs() {
    final key = switch (_referenceType) {
      'QUOTATION' => 'quotations',
      'PREORDER' => 'preOrders',
      'TEMP_RECEIPT' => 'receipts',
      'DELIVERY_NOTE' => 'deliveryNotes',
      _ => '',
    };
    return key.isEmpty
        ? const []
        : List<Map<String, dynamic>>.from(_lookup[key] as List? ?? const []);
  }

  Future<void> _selectSource(int? id) async {
    setState(() => _referenceId = id);
    if (id == null) return;
    try {
      final data = await _api.source(_referenceType, id);
      final c = Map<String, dynamic>.from(data['customer'] as Map? ?? const {});
      final lines = List<Map<String, dynamic>>.from(
        data['items'] as List? ?? const [],
      );
      setState(() {
        _customerId = (c['customerId'] as num?)?.toInt();
        _contact.text = '${c['contactName'] ?? ''}';
        _phone.text = '${c['contactPhone'] ?? ''}';
        _address.text = '${c['address'] ?? ''}';
        _lines = lines.where((r) => _num(r['deliveryQty']) > 0).map((r) {
          final source = (r['sourceDetailId'] as num?)?.toInt();
          return <String, dynamic>{
            ...r,
            'quotationDetailId': _referenceType == 'QUOTATION' ? source : null,
            'preOrderDetailId':
                _referenceType == 'PREORDER' || _referenceType == 'TEMP_RECEIPT'
                ? source
                : null,
            'parentDeliveryNoteDetailId': _referenceType == 'DELIVERY_NOTE'
                ? source
                : null,
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) _error('อ่านเอกสารอ้างอิงไม่ได้', e);
    }
  }

  void _customerChanged(int? id) {
    final c = _customers.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r?['customerId'] == id,
      orElse: () => null,
    );
    setState(() {
      _customerId = id;
      if (c != null) {
        _address.text = '${c['address'] ?? ''}';
        _contact.text = '${c['contactName1'] ?? c['contactName2'] ?? ''}';
        _phone.text = '${c['phone1'] ?? c['phone2'] ?? ''}';
      }
    });
  }

  Future<void> _editLine([int? index]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => _LineDialog(
        items: _items,
        initial: index == null ? null : _lines[index],
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _lines.add(result);
      } else {
        _lines[index] = result;
      }
    });
  }

  Future<void> _removeLine(int index) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: LaooColors.error),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes == true) setState(() => _lines.removeAt(index));
  }

  Map<String, dynamic> _body() => {
    'deliveryDate': _date.text,
    'referenceType': _referenceType,
    'referenceId': _referenceId,
    'customerId': _customerId,
    'contactName': _contact.text,
    'contactPhone': _phone.text,
    'deliveryAddress': _address.text,
    'transportBy': _transport.text,
    'trackingNo': _tracking.text,
    'remark': _remark.text,
    'items': _lines
        .map(
          (r) => {
            'itemId': r['itemId'],
            'quotationDetailId': r['quotationDetailId'],
            'preOrderDetailId': r['preOrderDetailId'],
            'parentDeliveryNoteDetailId': r['parentDeliveryNoteDetailId'],
            'orderedQty': _num(r['orderedQty']),
            'previouslyDeliveredQty': _num(r['previouslyDeliveredQty']),
            'deliveryQty': _num(r['deliveryQty']),
            'unitPrice': _num(r['unitPrice']),
            'remark': r['remark'],
          },
        )
        .toList(),
  };
  Future<void> _save() async {
    if (_form.currentState?.validate() != true || _customerId == null) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกลูกค้าและกรอกข้อมูลที่จำเป็น',
        error: true,
      );
      return;
    }
    if (_lines.isEmpty) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = _id == null
          ? await _api.create(_body())
          : await _api.update(_id!, _body());
      _id = (result['deliveryNoteId'] as num).toInt();
      _code.text = '${result['deliveryCode']}';
      if (mounted) showTimedSnackBar(context, message: 'บันทึกใบส่งของสำเร็จ');
    } catch (e) {
      if (mounted) _error('บันทึกใบส่งของไม่ได้', e);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _confirm() async {
    if (_id == null) return;
    try {
      await _api.confirm(_id!);
      await _loadDoc(_id!);
      if (mounted) {
        showTimedSnackBar(context, message: 'ยืนยันใบส่งของและตัดสต๊อกสำเร็จ');
      }
    } catch (e) {
      if (mounted) _error('ยืนยันใบส่งของไม่ได้', e);
    }
  }

  Future<void> _void() async {
    if (_id == null) return;
    try {
      await _api.voidDocument(_id!);
      await _loadDoc(_id!);
      if (mounted) {
        showTimedSnackBar(context, message: 'ยกเลิกใบส่งของและคืนสต๊อกสำเร็จ');
      }
    } catch (e) {
      if (mounted) _error('ยกเลิกใบส่งของไม่ได้', e);
    }
  }

  Future<void> _exportReceiptPdf() async {
    if (_customerId == null || _lines.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ยังส่งออก PDF ไม่ได้\nรายละเอียด: กรุณาเลือกลูกค้าและเพิ่มรายการสินค้าอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }

    final signature = await _askReceiptSignature(context);
    if (!signature.proceed) return;

    setState(() => _exportingPdf = true);
    try {
      final setup =
          companySetupController.current ?? await companySetupController.load();
      final customer = _selectedCustomer;
      final issuer = appAuthController.session?.displayName?.trim();
      final username = appAuthController.session?.username?.trim();
      final exportLines = _lines.map((line) {
        final item = _items.cast<Map<String, dynamic>?>().firstWhere(
          (value) => value?['itemId'] == line['itemId'],
          orElse: () => null,
        );
        return <String, dynamic>{
          ...line,
          'unitName': line['unitName'] ?? item?['unitName'],
        };
      }).toList();

      await DeliveryNoteReceiptPdfService.export(
        documentCode: _code.text,
        documentDate: DateTime.tryParse(_date.text) ?? DateTime.now(),
        companyName: DeliveryNoteReceiptPdfService.defaultCompanyName,
        companyAddress: DeliveryNoteReceiptPdfService.defaultCompanyAddress,
        companyPhone: setup.telephone ?? '',
        companyEmail: setup.email ?? '',
        companyTaxId: DeliveryNoteReceiptPdfService.defaultCompanyTaxId,
        customerCode: '${customer?['customerCode'] ?? ''}',
        customerName: '${customer?['customerName'] ?? ''}',
        customerAddress: _address.text,
        contactName: _contact.text,
        contactPhone: _phone.text,
        issuerName: issuer?.isNotEmpty == true
            ? issuer!
            : (username?.isNotEmpty == true ? username! : '-'),
        remark: _remark.text,
        items: exportLines,
        signatureBytes: signature.bytes,
        accent: workspaceThemeController.value.primary,
      );
    } catch (error) {
      if (mounted) {
        _error(
          'ไม่สามารถส่งออกใบเสร็จรับเงินเป็น PDF ได้\nกรุณาตรวจสอบข้อมูลเอกสารแล้วลองใหม่',
          error,
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu: _activeMenu,
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: const Color(0xFFF8F9FB),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  return Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _surface(
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              WorkspacePageTitle(
                                title:
                                    '$_menuName > ${_id == null ? 'เพิ่ม' : 'แก้ไข'}',
                                favoriteKey: _activeMenu,
                                titleColor: Colors.black,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _exportingPdf
                                        ? null
                                        : _exportReceiptPdf,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    icon: _exportingPdf
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.picture_as_pdf_outlined,
                                          ),
                                    label: const Text('ส่งออก PDF'),
                                  ),
                                  if (_status == 'DRAFT' && _id != null)
                                    FilledButton.icon(
                                      onPressed: _actions['edit'] == true
                                          ? _confirm
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: accent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check),
                                      label: const Text('ยืนยันตัดสต๊อก'),
                                    ),
                                  if (_status == 'CONFIRMED')
                                    FilledButton.icon(
                                      onPressed: _actions['edit'] == true
                                          ? _void
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: LaooColors.error,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.undo),
                                      label: const Text('ยกเลิก/คืนสต๊อก'),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        context.go('/company/delivery-notes'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('ยกเลิก'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _editable && !_saving
                                        ? _save
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('บันทึก'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ข้อมูลหัวเอกสาร',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 210,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _referenceType,
                                      decoration: _dec('อ้างอิงเอกสาร'),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'NONE',
                                          child: Text('ไม่อ้างอิง'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'QUOTATION',
                                          child: Text('ใบเสนอราคา'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'PREORDER',
                                          child: Text('ใบจองสินค้า'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'TEMP_RECEIPT',
                                          child: Text('ใบเสร็จชั่วคราว'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'DELIVERY_NOTE',
                                          child: Text('ใบส่งของเดิม'),
                                        ),
                                      ],
                                      onChanged: _editable
                                          ? (v) => setState(() {
                                              _referenceType = v ?? 'NONE';
                                              _referenceId = null;
                                              _lines = [];
                                            })
                                          : null,
                                    ),
                                  ),
                                  if (_referenceType != 'NONE')
                                    SizedBox(
                                      width: compact
                                          ? constraints.maxWidth
                                          : 300,
                                      child: DropdownButtonFormField<int>(
                                        initialValue: _referenceId,
                                        decoration: _dec('* เอกสารอ้างอิง'),
                                        items: _refs()
                                            .map(
                                              (r) => DropdownMenuItem<int>(
                                                value: (r['id'] as num).toInt(),
                                                child: Text(
                                                  '${r['code']} | ${r['customerName']}',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _editable
                                            ? _selectSource
                                            : null,
                                      ),
                                    ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 280,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _customerId,
                                      decoration: _dec('* ลูกค้า'),
                                      items: _customers
                                          .map(
                                            (r) => DropdownMenuItem<int>(
                                              value: (r['customerId'] as num)
                                                  .toInt(),
                                              child: Text(
                                                '${r['customerCode']} | ${r['customerName']}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _editable
                                          ? _customerChanged
                                          : null,
                                      validator: (v) =>
                                          v == null ? 'กรุณาเลือกลูกค้า' : null,
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 180,
                                    child: TextFormField(
                                      controller: _code,
                                      readOnly: true,
                                      decoration: _dec('เลขที่เอกสาร'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 180,
                                    child: TextFormField(
                                      controller: _date,
                                      readOnly: !_editable,
                                      decoration: _dec('* วันที่เอกสาร'),
                                      validator: (v) => v?.isEmpty == true
                                          ? 'กรุณาระบุวันที่'
                                          : null,
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 260,
                                    child: TextFormField(
                                      controller: _contact,
                                      readOnly: !_editable,
                                      decoration: _dec('ชื่อผู้ติดต่อ'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 200,
                                    child: TextFormField(
                                      controller: _phone,
                                      readOnly: !_editable,
                                      decoration: _dec('โทรศัพท์'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth - 44) / 2,
                                    child: TextFormField(
                                      controller: _address,
                                      readOnly: !_editable,
                                      maxLines: 2,
                                      decoration: _dec('* ที่อยู่จัดส่ง'),
                                      validator: (v) =>
                                          v?.trim().isEmpty == true
                                          ? 'กรุณาระบุที่อยู่จัดส่ง'
                                          : null,
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 220,
                                    child: TextFormField(
                                      controller: _transport,
                                      readOnly: !_editable,
                                      decoration: _dec('ขนส่งโดย'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 220,
                                    child: TextFormField(
                                      controller: _tracking,
                                      readOnly: !_editable,
                                      decoration: _dec('เลขติดตาม'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'รายการสินค้า',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _editable
                                        ? () => _editLine()
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('เพิ่มสินค้า'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_lines.isEmpty)
                                const SizedBox(
                                  height: 100,
                                  child: Center(
                                    child: Text('ยังไม่มีรายการสินค้า'),
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
                                      DataColumn(
                                        label: Text('จำนวนส่ง'),
                                        numeric: true,
                                      ),
                                      DataColumn(label: Text('หน่วยนับ')),
                                      DataColumn(
                                        label: Text('ราคา'),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('รวมเงิน'),
                                        numeric: true,
                                      ),
                                    ],
                                    rows: _lines.indexed.map((e) {
                                      final r = e.$2;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('${e.$1 + 1}')),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: _editable
                                                      ? () => _editLine(e.$1)
                                                      : null,
                                                  icon: Icon(
                                                    Icons.edit_outlined,
                                                    color: accent,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: _editable
                                                      ? () => _removeLine(e.$1)
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: LaooColors.error,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text('${r['itemCode']}')),
                                          DataCell(Text('${r['itemName']}')),
                                          DataCell(
                                            Text(_money(r['deliveryQty'])),
                                          ),
                                          DataCell(
                                            Text(
                                              '${r['unitName'] ?? r['unitCode'] ?? ''}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(_money(r['unitPrice'])),
                                          ),
                                          DataCell(
                                            Text(
                                              _money(
                                                _num(r['deliveryQty']) *
                                                    _num(r['unitPrice']),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _surface(
                          child: LayoutBuilder(
                            builder: (context, c) => c.maxWidth < 650
                                ? Column(
                                    children: [
                                      TextField(
                                        controller: _remark,
                                        readOnly: !_editable,
                                        maxLines: 3,
                                        decoration: _dec('หมายเหตุ'),
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'รวมเงิน ${_money(_total)}',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _remark,
                                          readOnly: !_editable,
                                          maxLines: 3,
                                          decoration: _dec('หมายเหตุ'),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      SizedBox(
                                        width: 300,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'รวมเงิน ${_money(_total)}',
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _LineDialog extends StatefulWidget {
  const _LineDialog({required this.items, this.initial});
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? initial;
  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  int? _itemId;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _remark;
  @override
  void initState() {
    super.initState();
    _itemId =
        (widget.initial?['itemId'] as num?)?.toInt() ??
        (widget.items.isEmpty
            ? null
            : (widget.items.first['itemId'] as num).toInt());
    _qty = TextEditingController(
      text: '${widget.initial?['deliveryQty'] ?? 1}',
    );
    _price = TextEditingController(
      text: '${widget.initial?['unitPrice'] ?? _item?['unitPrice'] ?? 0}',
    );
    _remark = TextEditingController(text: '${widget.initial?['remark'] ?? ''}');
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _remark.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _item => widget.items
      .cast<Map<String, dynamic>?>()
      .firstWhere((r) => r?['itemId'] == _itemId, orElse: () => null);
  double _n(String s) => double.tryParse(s) ?? 0;
  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: const Row(
        children: [
          Icon(Icons.inventory_2_outlined),
          SizedBox(width: 8),
          Text('รายการสินค้า', style: LaooTypography.screenCaptionStyle),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _itemId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '* สินค้า'),
              items: widget.items
                  .map(
                    (r) => DropdownMenuItem<int>(
                      value: (r['itemId'] as num).toInt(),
                      child: Text(
                        '${r['itemCode']} | ${r['itemName']} | คงเหลือ ${r['stockBalance']}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _itemId = v;
                _price.text = '${_item?['unitPrice'] ?? 0}';
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(labelText: '* จำนวนส่ง'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(labelText: 'ราคา'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remark,
              decoration: const InputDecoration(labelText: 'หมายเหตุ'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: () {
            final item = _item;
            if (item == null || _n(_qty.text) <= 0) return;
            Navigator.pop(context, <String, dynamic>{
              ...?widget.initial,
              ...item,
              'itemId': _itemId,
              'deliveryQty': _n(_qty.text),
              'orderedQty': widget.initial?['orderedQty'] ?? _n(_qty.text),
              'previouslyDeliveredQty':
                  widget.initial?['previouslyDeliveredQty'] ?? 0,
              'unitPrice': _n(_price.text),
              'remark': _remark.text,
            });
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }
}
