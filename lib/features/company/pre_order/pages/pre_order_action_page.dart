import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/pre_order_api.dart';

class PreOrderActionPage extends StatefulWidget {
  const PreOrderActionPage({this.preOrderId, super.key});

  final int? preOrderId;

  @override
  State<PreOrderActionPage> createState() => _PreOrderActionPageState();
}

class _PreOrderActionPageState extends State<PreOrderActionPage> {
  static const _activeMenu = 'companyPreOrders';
  final _api = PreOrderApi();
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _date = TextEditingController();
  final _expectedDate = TextEditingController();
  final _customerCode = TextEditingController();
  final _customerName = TextEditingController();
  final _customerAddress = TextEditingController();
  final _customerEmail = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _deposit = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  final _remark = TextEditingController();

  int? _preOrderId;
  int? _quotationId;
  String _quoteCode = '';
  String _menuName = 'ใบรับจองสินค้า';
  String _status = 'DRAFT';
  Map<String, bool> _actions = const {};
  List<Map<String, dynamic>> _quotations = const [];
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => _preOrderId != null;
  bool get _canSave =>
      _isEdit ? _actions['edit'] == true : _actions['create'] == true;
  double get _total =>
      _lines.fold<double>(0, (sum, line) => sum + _number(line['amount']));
  double get _balance =>
      math.max(0, _total - _number(_deposit.text) - _number(_paid.text));

  @override
  void initState() {
    super.initState();
    _preOrderId = widget.preOrderId;
    _date.text = _isoDate(DateTime.now());
    _resolveMenuName();
    _load();
  }

  Future<void> _resolveMenuName() async {
    try {
      final value = await NavigationMenuRepository().resolveMenuName(
        routeName: _activeMenu,
        fallback: 'ใบรับจองสินค้า',
      );
      if (mounted && value.trim().isNotEmpty) {
        setState(() => _menuName = value.trim());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _api.dispose();
    for (final controller in [
      _code,
      _date,
      _expectedDate,
      _customerCode,
      _customerName,
      _customerAddress,
      _customerEmail,
      _contactName,
      _contactPhone,
      _deposit,
      _paid,
      _remark,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

  void _disposeControllersAfterDialog(
    Iterable<TextEditingController> controllers,
  ) {
    // showDialog completes before its reverse transition has fully removed the
    // route from the overlay. Disposing a controller immediately can leave an
    // InputDecorator/Form dependent attached while the inherited widgets are
    // being deactivated and trigger `_dependents.isEmpty` in debug mode.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _money(dynamic value) {
    final amount = _number(value);
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _displayDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  Future<void> _load() async {
    try {
      final lookup = await _api.lookup();
      final actions = await _api.actions();
      if (!mounted) return;
      setState(() {
        _quotations = List<Map<String, dynamic>>.from(
          lookup['quotations'] as List? ?? const [],
        );
        _items = List<Map<String, dynamic>>.from(
          lookup['items'] as List? ?? const [],
        );
        _actions = actions;
      });
      if (_preOrderId != null) {
        await _loadDocument(_preOrderId!);
      }
    } catch (error) {
      if (mounted) _showError('ไม่สามารถเปิดหน้าใบรับจองสินค้าได้', error);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDocument(int id) async {
    final result = await _api.get(id);
    final header = Map<String, dynamic>.from(result['header'] as Map);
    final lines = List<Map<String, dynamic>>.from(
      result['items'] as List? ?? const [],
    );
    if (!mounted) return;
    setState(() {
      _preOrderId = (header['preOrderId'] as num).toInt();
      _quotationId = (header['quotationId'] as num).toInt();
      _quoteCode = '${header['quoteCode'] ?? ''}';
      _code.text = '${header['preOrderCode'] ?? ''}';
      _date.text = '${header['preOrderDate'] ?? ''}'.split('T').first;
      _expectedDate.text = header['expectedDate'] == null
          ? ''
          : '${header['expectedDate']}'.split('T').first;
      _customerCode.text = '${header['customerCode'] ?? ''}';
      _customerName.text = '${header['customerName'] ?? ''}';
      _customerAddress.text = '${header['customerAddress'] ?? ''}';
      _customerEmail.text = '${header['customerEmail'] ?? ''}';
      _contactName.text = '${header['contactName'] ?? ''}';
      _contactPhone.text = '${header['contactPhone'] ?? ''}';
      _deposit.text = '${header['depositAmount'] ?? 0}';
      _paid.text = '${header['paidAmount'] ?? 0}';
      _status = '${header['statusCode'] ?? 'DRAFT'}';
      _remark.text = '${header['remark'] ?? ''}';
      _lines = lines.map(_normalizeLine).toList();
    });
  }

  Map<String, dynamic> _normalizeLine(Map<String, dynamic> source) {
    final type = '${source['discountType'] ?? 'N'}'.toUpperCase();
    return <String, dynamic>{
      ...source,
      'quantity': _number(source['quantity']),
      'allocatedQty': _number(source['allocatedQty']),
      'deliveredQty': _number(source['deliveredQty']),
      'unitPrice': _number(source['unitPrice']),
      'discountType': type,
      'discountValue': type == 'P'
          ? _number(source['discountPercent'])
          : type == 'A'
          ? _number(source['discountAmount'])
          : 0,
      'amount': _number(source['amount']),
      'statusCode': '${source['statusCode'] ?? 'WAITING_STOCK'}',
    };
  }

  void _showError(String message, Object error) {
    showTimedSnackBar(
      context,
      message: '$message\nรายละเอียด: $error',
      error: true,
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final accent = workspaceThemeController.value.primary;
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        ),
        child: child!,
      ),
    );
    if (value != null) setState(() => controller.text = _isoDate(value));
  }

  Future<void> _selectQuotation() async {
    final search = TextEditingController();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = workspaceThemeController.value.primary;
          final query = search.text.trim().toLowerCase();
          final rows = _quotations.where((row) {
            return query.isEmpty ||
                '${row['quoteCode']} ${row['customerCode']} ${row['customerName']}'
                    .toLowerCase()
                    .contains(query);
          }).toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Row(
              children: [
                Icon(Icons.request_quote_outlined, color: accent),
                const SizedBox(width: 8),
                Text(
                  'เลือกใบเสนอราคา',
                  style: LaooTypography.screenCaptionStyle,
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: 460,
              child: Column(
                children: [
                  const Divider(color: LaooColors.border),
                  TextField(
                    controller: search,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'ค้นหาเลขที่ใบเสนอราคา/ลูกค้า',
                      prefixIcon: Icon(Icons.search, color: accent),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                        borderSide: BorderSide(
                          color: accent.withValues(alpha: .45),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                        borderSide: BorderSide(color: accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: LaooColors.border),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          title: Text(
                            '${row['quoteCode']} | ${_displayDate(row['quoteDate'])}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${row['customerCode']} | ${row['customerName']}  •  ${_money(row['netAmount'])}',
                          ),
                          trailing: Icon(Icons.chevron_right, color: accent),
                          onTap: () => Navigator.pop(dialogContext, row),
                        );
                      },
                    ),
                  ),
                  const Divider(color: LaooColors.border),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                child: const Text('ปิด'),
              ),
            ],
          );
        },
      ),
    );
    _disposeControllersAfterDialog([search]);
    if (selected == null || !mounted) return;
    try {
      setState(() => _loading = true);
      final result = await _api.quotation(
        (selected['quotationId'] as num).toInt(),
      );
      final header = Map<String, dynamic>.from(result['quotation'] as Map);
      final lines = List<Map<String, dynamic>>.from(
        result['items'] as List? ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _quotationId = (header['id'] as num).toInt();
        _quoteCode = '${header['quoteCode'] ?? selected['quoteCode'] ?? ''}';
        _customerCode.text = '${header['customerCode'] ?? ''}';
        _customerName.text = '${header['customerName'] ?? ''}';
        _customerAddress.text = '${header['address'] ?? ''}';
        _customerEmail.text = '${header['email'] ?? ''}';
        _contactName.text = '${header['contactName'] ?? ''}';
        _contactPhone.text = '${header['contactPhone'] ?? ''}';
        _lines = lines.map(_normalizeLine).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('ไม่สามารถดึงข้อมูลจากใบเสนอราคาได้', error);
    }
  }

  double _lineAmount(Map<String, dynamic> line) {
    final before = _number(line['quantity']) * _number(line['unitPrice']);
    final type = '${line['discountType'] ?? 'N'}';
    final value = _number(line['discountValue']);
    final discount = type == 'P'
        ? before * value / 100
        : type == 'A'
        ? value
        : 0;
    return math.max(0, before - discount);
  }

  Future<void> _editLine({int? index}) async {
    if (index == null && _items.isEmpty) {
      _showError(
        'ไม่สามารถเพิ่มสินค้าได้',
        'ยังไม่มีรายการสินค้าให้เลือก กรุณาสร้างสินค้าและตรวจสอบสิทธิ์หรือการเชื่อมต่อ API ก่อนลองใหม่',
      );
      return;
    }
    final source = index == null
        ? <String, dynamic>{
            'itemId': _items.isEmpty ? null : _items.first['itemId'],
            'quantity': 1.0,
            'allocatedQty': 0.0,
            'deliveredQty': 0.0,
            'unitPrice': _items.isEmpty ? 0 : _items.first['unitPrice'],
            'discountType': 'N',
            'discountValue': 0.0,
            'statusCode': 'WAITING_STOCK',
            'remark': '',
          }
        : Map<String, dynamic>.from(_lines[index]);
    int? itemId = (source['itemId'] as num?)?.toInt();
    String discountType = '${source['discountType'] ?? 'N'}';
    String lineStatus = '${source['statusCode'] ?? 'WAITING_STOCK'}';
    final quantity = TextEditingController(text: '${source['quantity'] ?? 1}');
    final allocated = TextEditingController(
      text: '${source['allocatedQty'] ?? 0}',
    );
    final delivered = TextEditingController(
      text: '${source['deliveredQty'] ?? 0}',
    );
    final price = TextEditingController(text: '${source['unitPrice'] ?? 0}');
    final discount = TextEditingController(
      text: '${source['discountValue'] ?? 0}',
    );
    final remark = TextEditingController(text: '${source['remark'] ?? ''}');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedItem = _items.cast<Map<String, dynamic>?>().firstWhere(
            (item) => (item?['itemId'] as num?)?.toInt() == itemId,
            orElse: () => null,
          );
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: workspaceThemeController.value.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  index == null ? 'เพิ่มรายการสินค้า' : 'แก้ไขรายการสินค้า',
                  style: LaooTypography.screenCaptionStyle,
                ),
              ],
            ),
            content: SizedBox(
              width: 760,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Divider(color: LaooColors.border),
                      DropdownButtonFormField<int>(
                        initialValue: itemId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '* สินค้า',
                        ),
                        items: _items
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: (item['itemId'] as num).toInt(),
                                child: Text(
                                  '${item['itemCode']} | ${item['itemName']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          final item = _items.firstWhere(
                            (row) => (row['itemId'] as num).toInt() == value,
                          );
                          setDialogState(() {
                            itemId = value;
                            price.text = '${item['unitPrice'] ?? 0}';
                          });
                        },
                        validator: (value) =>
                            value == null ? 'กรุณาเลือกสินค้า' : null,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'หน่วยนับ: ${selectedItem?['unitName'] ?? '-'}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          _numberField('จำนวนจอง', quantity, required: true),
                          _numberField('จำนวนจัดสรร', allocated),
                          _numberField('จำนวนส่งมอบ', delivered),
                          _numberField('ราคา', price, required: true),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 230,
                            child: DropdownButtonFormField<String>(
                              initialValue: discountType,
                              decoration: const InputDecoration(
                                labelText: 'รูปแบบส่วนลด',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'N',
                                  child: Text('ไม่ลด'),
                                ),
                                DropdownMenuItem(
                                  value: 'P',
                                  child: Text('เปอร์เซ็นต์'),
                                ),
                                DropdownMenuItem(
                                  value: 'A',
                                  child: Text('จำนวนเงิน'),
                                ),
                              ],
                              onChanged: (value) => setDialogState(
                                () => discountType = value ?? 'N',
                              ),
                            ),
                          ),
                          _numberField(
                            discountType == 'P'
                                ? 'ส่วนลด (%)'
                                : 'ส่วนลด (จำนวนเงิน)',
                            discount,
                            enabled: discountType != 'N',
                          ),
                          SizedBox(
                            width: 230,
                            child: DropdownButtonFormField<String>(
                              initialValue: lineStatus,
                              decoration: const InputDecoration(
                                labelText: 'สถานะรายการ',
                              ),
                              items: _detailStatusItems,
                              onChanged: (value) => setDialogState(
                                () => lineStatus = value ?? 'WAITING_STOCK',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: remark,
                        decoration: const InputDecoration(
                          labelText: 'หมายเหตุรายการ',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: LaooColors.border),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
                label: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () {
                  if (form.currentState?.validate() != true || itemId == null) {
                    return;
                  }
                  final item = _items.firstWhere(
                    (row) => (row['itemId'] as num).toInt() == itemId,
                  );
                  final result = <String, dynamic>{
                    ...source,
                    ...item,
                    'itemId': itemId,
                    'quantity': _number(quantity.text),
                    'allocatedQty': _number(allocated.text),
                    'deliveredQty': _number(delivered.text),
                    'unitPrice': _number(price.text),
                    'discountType': discountType,
                    'discountValue': discountType == 'N'
                        ? 0
                        : _number(discount.text),
                    'statusCode': lineStatus,
                    'remark': remark.text.trim(),
                  };
                  result['amount'] = _lineAmount(result);
                  Navigator.pop(dialogContext, result);
                },
                icon: const Icon(Icons.check),
                label: const Text('บันทึกรายการ'),
              ),
            ],
          );
        },
      ),
    );
    _disposeControllersAfterDialog([
      quantity,
      allocated,
      delivered,
      price,
      discount,
      remark,
    ]);
    if (saved == null || !mounted) return;
    setState(() {
      if (index == null) {
        _lines.add(saved);
      } else {
        _lines[index] = saved;
      }
    });
  }

  Widget _numberField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 170,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
        ],
        decoration: InputDecoration(labelText: '${required ? '* ' : ''}$label'),
        validator: required
            ? (value) => _number(value) <= 0 ? 'กรุณาระบุค่ามากกว่า 0' : null
            : null,
      ),
    );
  }

  Future<void> _removeLine(int index) async {
    final line = _lines[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
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
                color: workspaceThemeController.value.primary.withValues(
                  alpha: .10,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ต้องการลบ ${line['itemCode']} - ${line['itemName']} หรือไม่?',
              ),
            ),
            const SizedBox(height: 12),
            const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _lines.removeAt(index));
    }
  }

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_quotationId == null) {
      showTimedSnackBar(
        context,
        message:
            'ไม่สามารถบันทึกใบรับจองสินค้าได้\nรายละเอียด: กรุณาเลือกใบเสนอราคา',
        error: true,
      );
      return;
    }
    if (_lines.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ไม่สามารถบันทึกใบรับจองสินค้าได้\nรายละเอียด: กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'quotationId': _quotationId,
      'preOrderDate': _date.text,
      'expectedDate': _expectedDate.text.trim().isEmpty
          ? null
          : _expectedDate.text,
      'contactName': _contactName.text.trim(),
      'contactPhone': _contactPhone.text.trim(),
      'depositAmount': _number(_deposit.text),
      'paidAmount': _number(_paid.text),
      'statusCode': _status,
      'remark': _remark.text.trim(),
      'items': _lines
          .map(
            (line) => <String, dynamic>{
              'quotationDetailId': line['quotationDetailId'],
              'itemId': line['itemId'],
              'quantity': _number(line['quantity']),
              'allocatedQty': _number(line['allocatedQty']),
              'deliveredQty': _number(line['deliveredQty']),
              'unitPrice': _number(line['unitPrice']),
              'discountType': line['discountType'] ?? 'N',
              'discountValue': _number(line['discountValue']),
              'statusCode': line['statusCode'] ?? 'WAITING_STOCK',
              'remark': line['remark'],
            },
          )
          .toList(),
    };
    try {
      final result = _preOrderId == null
          ? await _api.create(body)
          : await _api.update(_preOrderId!, body);
      if (!mounted) return;
      setState(() {
        _preOrderId = (result['preOrderId'] as num).toInt();
        _code.text = '${result['preOrderCode']}';
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTimedSnackBar(context, message: 'บันทึกข้อมูลใบรับจองสินค้าสำเร็จ');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('ไม่สามารถบันทึกข้อมูลใบรับจองสินค้าได้', error);
    }
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _readOnly(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: LaooColors.background,
      ),
    );
  }

  Widget _dateField(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: () => _pickDate(controller),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'กรุณาระบุวันที่เอกสาร'
                : null
          : null,
    );
  }

  Widget _headerCard(bool compact) {
    final width = compact ? double.infinity : 260.0;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลใบรับจองสินค้า',
            style: TextStyle(
              color: LaooColors.textPrimary,
              fontSize: LaooTypography.sectionTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: compact ? double.infinity : 420,
                child: TextFormField(
                  readOnly: true,
                  key: ValueKey(_quoteCode),
                  initialValue: _quoteCode,
                  decoration: InputDecoration(
                    labelText: '* อ้างอิงใบเสนอราคา',
                    hintText: 'กดค้นหาใบเสนอราคา',
                    suffixIcon: IconButton(
                      onPressed: _canSave ? _selectQuotation : null,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onTap: _canSave ? _selectQuotation : null,
                  validator: (_) =>
                      _quotationId == null ? 'กรุณาเลือกใบเสนอราคา' : null,
                ),
              ),
              SizedBox(width: width, child: _readOnly('เลขที่ใบจอง', _code)),
              SizedBox(
                width: width,
                child: _dateField('* วันที่เอกสาร', _date, required: true),
              ),
              SizedBox(
                width: width,
                child: _dateField('วันที่คาดว่าจะได้รับสินค้า', _expectedDate),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_status),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'สถานะเอกสาร'),
                  items: _headerStatusItems,
                  onChanged: _canSave
                      ? (value) => setState(() => _status = value ?? 'DRAFT')
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: LaooColors.border),
          const SizedBox(height: 8),
          const Text(
            'ข้อมูลลูกค้า',
            style: TextStyle(
              color: LaooColors.textPrimary,
              fontSize: LaooTypography.sectionTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: compact ? double.infinity : 220,
                child: _readOnly('รหัสลูกค้า', _customerCode),
              ),
              SizedBox(
                width: compact ? double.infinity : 460,
                child: _readOnly('ชื่อลูกค้า', _customerName),
              ),
              SizedBox(
                width: compact ? double.infinity : 320,
                child: _readOnly('Email', _customerEmail),
              ),
              SizedBox(
                width: compact ? double.infinity : 520,
                child: _readOnly('ที่อยู่ลูกค้า', _customerAddress),
              ),
              SizedBox(
                width: compact ? double.infinity : 300,
                child: TextFormField(
                  controller: _contactName,
                  decoration: const InputDecoration(labelText: 'ชื่อผู้ติดต่อ'),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 260,
                child: TextFormField(
                  controller: _contactPhone,
                  decoration: const InputDecoration(
                    labelText: 'เบอร์โทรติดต่อ',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailCard(bool compact, Color accent) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'รายการสินค้า',
                  style: TextStyle(
                    color: LaooColors.textPrimary,
                    fontSize: LaooTypography.sectionTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _canSave ? () => _editLine() : null,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรายการ'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('ยังไม่มีรายการสินค้า')),
            )
          else if (compact)
            Column(
              children: [
                for (var index = 0; index < _lines.length; index++) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LaooColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_lines[index]['itemCode']} | ${_lines[index]['itemName']}',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _canSave
                                  ? () => _editLine(index: index)
                                  : null,
                              icon: Icon(Icons.edit_outlined, color: accent),
                            ),
                            IconButton(
                              onPressed: _canSave
                                  ? () => _removeLine(index)
                                  : null,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text('จำนวน ${_money(_lines[index]['quantity'])}'),
                            Text('หน่วย ${_lines[index]['unitName']}'),
                            Text('ราคา ${_money(_lines[index]['unitPrice'])}'),
                            Text('รวม ${_money(_lines[index]['amount'])}'),
                            Text(
                              'สถานะ ${_statusName(_lines[index]['statusCode'])}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < _lines.length - 1) const SizedBox(height: 6),
                ],
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      accent.withValues(alpha: .10),
                    ),
                    dividerThickness: .6,
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('รหัสสินค้า')),
                      DataColumn(label: Text('ชื่อสินค้า')),
                      DataColumn(label: Text('จำนวน'), numeric: true),
                      DataColumn(label: Text('จัดสรร'), numeric: true),
                      DataColumn(label: Text('ส่งมอบ'), numeric: true),
                      DataColumn(label: Text('หน่วยนับ')),
                      DataColumn(label: Text('ราคา'), numeric: true),
                      DataColumn(label: Text('ส่วนลด'), numeric: true),
                      DataColumn(label: Text('รวมเงิน'), numeric: true),
                      DataColumn(label: Text('สถานะ')),
                    ],
                    rows: [
                      for (var index = 0; index < _lines.length; index++)
                        DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _canSave
                                        ? () => _editLine(index: index)
                                        : null,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: accent,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _canSave
                                        ? () => _removeLine(index)
                                        : null,
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text('${_lines[index]['itemCode']}')),
                            DataCell(Text('${_lines[index]['itemName']}')),
                            DataCell(Text(_money(_lines[index]['quantity']))),
                            DataCell(
                              Text(_money(_lines[index]['allocatedQty'])),
                            ),
                            DataCell(
                              Text(_money(_lines[index]['deliveredQty'])),
                            ),
                            DataCell(Text('${_lines[index]['unitName']}')),
                            DataCell(Text(_money(_lines[index]['unitPrice']))),
                            DataCell(Text(_discountText(_lines[index]))),
                            DataCell(Text(_money(_lines[index]['amount']))),
                            DataCell(
                              Text(_statusName(_lines[index]['statusCode'])),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _discountText(Map<String, dynamic> line) {
    return switch ('${line['discountType']}') {
      'P' => '${_money(line['discountValue'])}%',
      'A' => _money(line['discountValue']),
      _ => '-',
    };
  }

  String _statusName(dynamic value) {
    return switch (value?.toString().toUpperCase()) {
      'DRAFT' => 'ร่าง',
      'CONFIRMED' => 'ยืนยันแล้ว',
      'WAITING_STOCK' => 'รอสินค้า',
      'PARTIAL_STOCK' => 'สินค้าเข้าบางส่วน',
      'READY' => 'พร้อมส่ง',
      'DELIVERED' => 'ส่งมอบแล้ว',
      'CANCELLED' => 'ยกเลิก',
      'CLOSED' => 'ปิดเอกสาร',
      _ => value?.toString() ?? '-',
    };
  }

  Widget _summaryCard(bool compact) {
    final summaryWidth = compact ? double.infinity : 270.0;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปยอดเงิน',
            style: TextStyle(
              color: LaooColors.textPrimary,
              fontSize: LaooTypography.sectionTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (compact)
            Column(
              children: [
                _remarkField(),
                const SizedBox(height: 12),
                SizedBox(width: summaryWidth, child: _summaryFields()),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _remarkField()),
                const SizedBox(width: 20),
                SizedBox(width: summaryWidth, child: _summaryFields()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _remarkField() {
    return TextField(
      controller: _remark,
      maxLines: 4,
      decoration: const InputDecoration(labelText: 'หมายเหตุ'),
    );
  }

  Widget _summaryFields() {
    return Column(
      children: [
        _summaryLine('รวมเงิน', _money(_total)),
        const SizedBox(height: 8),
        TextField(
          controller: _deposit,
          enabled: _canSave,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'เงินมัดจำ'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _paid,
          enabled: _canSave,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'ชำระแล้ว'),
        ),
        const SizedBox(height: 8),
        _summaryLine('คงเหลือ', _money(_balance), strong: true),
      ],
    );
  }

  Widget _summaryLine(String label, String value, {bool strong = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LaooColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
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
                  final compact = constraints.maxWidth < 850;
                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _surface(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: WorkspacePageTitle(
                                  title:
                                      '$_menuName > ${_isEdit ? 'แก้ไข' : 'เพิ่ม'}',
                                  favoriteKey: _activeMenu,
                                  titleColor: Colors.black,
                                ),
                              ),
                              OutlinedButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: () =>
                                    context.go('/company/pre-orders'),
                                icon: const Icon(Icons.close),
                                label: const Text('ยกเลิก'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: _saving || !_canSave ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _headerCard(compact),
                        const SizedBox(height: 8),
                        _detailCard(compact, accent),
                        const SizedBox(height: 8),
                        _summaryCard(compact),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  static const _headerStatusItems = [
    DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
    DropdownMenuItem(value: 'CONFIRMED', child: Text('ยืนยันแล้ว')),
    DropdownMenuItem(value: 'WAITING_STOCK', child: Text('รอสินค้า')),
    DropdownMenuItem(value: 'PARTIAL_STOCK', child: Text('สินค้าเข้าบางส่วน')),
    DropdownMenuItem(value: 'READY', child: Text('พร้อมส่ง')),
    DropdownMenuItem(value: 'DELIVERED', child: Text('ส่งมอบแล้ว')),
    DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
    DropdownMenuItem(value: 'CLOSED', child: Text('ปิดเอกสาร')),
  ];

  static const _detailStatusItems = [
    DropdownMenuItem(value: 'WAITING_STOCK', child: Text('รอสินค้า')),
    DropdownMenuItem(value: 'PARTIAL_STOCK', child: Text('สินค้าเข้าบางส่วน')),
    DropdownMenuItem(value: 'READY', child: Text('พร้อมส่ง')),
    DropdownMenuItem(value: 'DELIVERED', child: Text('ส่งมอบแล้ว')),
    DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
    DropdownMenuItem(value: 'CLOSED', child: Text('ปิดเอกสาร')),
  ];
}
