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
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../../delivery_note/services/delivery_note_receipt_pdf_service.dart';
import '../data/temporary_receipt_api.dart';

Future<({bool proceed, Uint8List? bytes})> _askActionReceiptSignature(
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

class TemporaryReceiptActionPage extends StatefulWidget {
  const TemporaryReceiptActionPage({this.receiptId, super.key});

  final int? receiptId;

  @override
  State<TemporaryReceiptActionPage> createState() =>
      _TemporaryReceiptActionPageState();
}

class _TemporaryReceiptActionPageState
    extends State<TemporaryReceiptActionPage> {
  static const _activeMenu = 'companyTemporaryReceipts';
  final _api = TemporaryReceiptApi();
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _date = TextEditingController();
  final _customerCode = TextEditingController();
  final _customerName = TextEditingController();
  final _address = TextEditingController();
  final _taxId = TextEditingController();
  final _contact = TextEditingController();
  final _receivedFrom = TextEditingController();
  final _remark = TextEditingController();

  int? _receiptId;
  int? _customerId;
  int? _referenceId;
  String _menuName = 'ใบเสร็จรับเงินชั่วคราว';
  String _referenceType = 'NONE';
  String _status = 'DRAFT';
  Map<String, bool> _actions = const {};
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _quotations = const [];
  List<Map<String, dynamic>> _preOrders = const [];
  List<Map<String, dynamic>> _paymentMethods = const [];
  List<Map<String, dynamic>> _payments = [];
  double _referenceAmount = 0;
  double _previouslyReceived = 0;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => _receiptId != null;
  bool get _canSave =>
      _isEdit ? _actions['edit'] == true : _actions['create'] == true;
  double get _receivedAmount =>
      _payments.fold<double>(0, (sum, row) => sum + _number(row['amount']));
  double get _balanceAmount =>
      math.max(0, _referenceAmount - _previouslyReceived - _receivedAmount);

  @override
  void initState() {
    super.initState();
    _receiptId = widget.receiptId;
    _date.text = _isoDate(DateTime.now());
    _resolveMenuName();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    for (final controller in [
      _code,
      _date,
      _customerCode,
      _customerName,
      _address,
      _taxId,
      _contact,
      _receivedFrom,
      _remark,
    ]) {
      controller.dispose();
    }
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

  double _number(dynamic raw) =>
      double.tryParse(raw?.toString().replaceAll(',', '') ?? '') ?? 0;

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _money(dynamic raw) => _number(raw)
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  void _error(String message, Object error) {
    showTimedSnackBar(
      context,
      message: '$message\nรายละเอียด: $error',
      error: true,
    );
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([_api.lookup(), _api.actions()]);
      if (!mounted) return;
      final lookup = values[0];
      setState(() {
        _customers = List<Map<String, dynamic>>.from(
          lookup['customers'] as List? ?? const [],
        );
        _quotations = List<Map<String, dynamic>>.from(
          lookup['quotations'] as List? ?? const [],
        );
        _preOrders = List<Map<String, dynamic>>.from(
          lookup['preOrders'] as List? ?? const [],
        );
        _paymentMethods = List<Map<String, dynamic>>.from(
          lookup['paymentMethods'] as List? ?? const [],
        );
        _actions = values[1] as Map<String, bool>;
      });
      if (_receiptId != null) await _loadDocument(_receiptId!);
    } catch (error) {
      if (mounted) _error('ไม่สามารถเปิดหน้าใบเสร็จรับเงินชั่วคราวได้', error);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDocument(int id) async {
    final data = await _api.get(id);
    final header = Map<String, dynamic>.from(data['header'] as Map);
    final quotationId = (header['quotationId'] as num?)?.toInt();
    final preOrderId = (header['preOrderId'] as num?)?.toInt();
    if (!mounted) return;
    setState(() {
      _receiptId = (header['temporaryReceiptId'] as num).toInt();
      _referenceType = preOrderId != null
          ? 'PREORDER'
          : quotationId != null
          ? 'QUOTATION'
          : 'NONE';
      _referenceId = preOrderId ?? quotationId;
      _customerId = (header['customerId'] as num).toInt();
      _referenceAmount = _number(header['referenceAmount']);
      _previouslyReceived = _number(header['previouslyReceivedAmount']);
      _status = header['statusCode']?.toString() ?? 'DRAFT';
      _code.text = header['receiptCode']?.toString() ?? '';
      _date.text = _isoDate(
        DateTime.tryParse(header['receiptDate']?.toString() ?? '') ??
            DateTime.now(),
      );
      _customerCode.text = header['customerCode']?.toString() ?? '';
      _customerName.text = header['customerName']?.toString() ?? '';
      _address.text = header['address']?.toString() ?? '';
      _taxId.text = header['taxId']?.toString() ?? '';
      _contact.text = header['contactName']?.toString() ?? '';
      _receivedFrom.text = header['receivedFrom']?.toString() ?? '';
      _remark.text = header['remark']?.toString() ?? '';
      _payments = List<Map<String, dynamic>>.from(
        data['payments'] as List? ?? const [],
      );
    });
  }

  void _selectCustomer(int? id) {
    if (id == null) return;
    final customer = _customers.firstWhere(
      (row) => (row['customerId'] as num).toInt() == id,
    );
    setState(() {
      _customerId = id;
      _customerCode.text = customer['customerCode']?.toString() ?? '';
      _customerName.text = customer['customerName']?.toString() ?? '';
      _address.text = customer['address']?.toString() ?? '';
      _taxId.text = customer['taxId']?.toString() ?? '';
      _contact.text = customer['contactName']?.toString() ?? '';
      _receivedFrom.text = customer['customerName']?.toString() ?? '';
    });
  }

  void _changeReferenceType(String? value) {
    setState(() {
      _referenceType = value ?? 'NONE';
      _referenceId = null;
      _referenceAmount = 0;
      _previouslyReceived = 0;
      if (_referenceType != 'NONE') {
        _customerId = null;
        for (final controller in [
          _customerCode,
          _customerName,
          _address,
          _taxId,
          _contact,
          _receivedFrom,
        ]) {
          controller.clear();
        }
      }
    });
  }

  void _selectReference(int? id) {
    if (id == null) return;
    final source = (_referenceType == 'QUOTATION' ? _quotations : _preOrders)
        .firstWhere((row) {
          final key = _referenceType == 'QUOTATION'
              ? row['quotationId']
              : row['preOrderId'];
          return (key as num).toInt() == id;
        });
    setState(() {
      _referenceId = id;
      _referenceAmount = _number(source['referenceAmount']);
      _previouslyReceived = _number(source['previouslyReceivedAmount']);
    });
    _selectCustomer((source['customerId'] as num).toInt());
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: workspaceThemeController.value.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (value != null) setState(() => _date.text = _isoDate(value));
  }

  Future<void> _editPayment([int? index]) async {
    if (_paymentMethods.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ยังไม่มีช่องทางรับเงิน\nรายละเอียด: กรุณาเพิ่ม TDSTMasterCont GroupCode = 005 ก่อน',
        error: true,
      );
      return;
    }
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PaymentDialog(
        methods: _paymentMethods,
        initial: index == null ? null : _payments[index],
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (index == null) {
        _payments.add(value);
      } else {
        _payments[index] = value;
      }
    });
  }

  Future<void> _removePayment(int index) async {
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text('ต้องการลบรายการรับเงินนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _payments.removeAt(index));
    }
  }

  String _methodName(dynamic code) {
    for (final row in _paymentMethods) {
      if (row['code']?.toString() == code?.toString()) {
        return row['name']?.toString() ?? '$code';
      }
    }
    return code?.toString() ?? '-';
  }

  Future<void> _exportPdf() async {
    if (_customerId == null || _payments.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ยังพิมพ์ใบเสร็จรับเงินชั่วคราวไม่ได้\nรายละเอียด: กรุณาเลือกลูกค้าและเพิ่มรายการรับเงินอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    final signature = await _askActionReceiptSignature(context);
    if (!signature.proceed) return;
    try {
      final setup =
          companySetupController.current ?? await companySetupController.load();
      final noReference = _referenceType == 'NONE';
      final items = _payments
          .map(
            (payment) => <String, dynamic>{
              'itemName': noReference && _remark.text.trim().isNotEmpty
                  ? _remark.text.trim()
                  : _methodName(payment['paymentMethodCode']),
              'deliveryQty': 1,
              'unitPrice': payment['amount'] ?? 0,
              'unitName': payment['referenceNo'] ?? '',
            },
          )
          .toList();
      await DeliveryNoteReceiptPdfService.export(
        documentCode: _code.text,
        documentDate: DateTime.tryParse(_date.text) ?? DateTime.now(),
        companyName: DeliveryNoteReceiptPdfService.defaultCompanyName,
        companyAddress: DeliveryNoteReceiptPdfService.defaultCompanyAddress,
        companyPhone: setup.telephone ?? '',
        companyEmail: setup.email ?? '',
        companyTaxId: DeliveryNoteReceiptPdfService.defaultCompanyTaxId,
        customerCode: '',
        customerName: _customerName.text,
        customerAddress: _address.text,
        contactName: _contact.text,
        contactPhone: '',
        issuerName: 'โชคชัย วันดี',
        remark: _remark.text,
        items: items,
        signatureBytes: signature.bytes,
        documentTitle: 'ใบเสร็จรับเงินชั่วคราว',
        accent: workspaceThemeController.value.primary,
      );
    } catch (error) {
      if (mounted) _error('ไม่สามารถพิมพ์ใบเสร็จรับเงินชั่วคราวได้', error);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_customerId == null) {
      showTimedSnackBar(context, message: 'กรุณาเลือกลูกค้า', error: true);
      return;
    }
    if (_referenceType != 'NONE' && _referenceId == null) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกเอกสารอ้างอิง',
        error: true,
      );
      return;
    }
    if (_payments.isEmpty) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเพิ่มรายการรับเงิน',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'receiptDate': _date.text,
      'quotationId': _referenceType == 'QUOTATION' ? _referenceId : null,
      'preOrderId': _referenceType == 'PREORDER' ? _referenceId : null,
      'customerId': _customerId,
      'contactName': _contact.text.trim(),
      'receivedFrom': _receivedFrom.text.trim(),
      'statusCode': _status,
      'remark': _remark.text.trim(),
      'payments': _payments,
    };
    try {
      final result = _receiptId == null
          ? await _api.create(body)
          : await _api.update(_receiptId!, body);
      if (!mounted) return;
      setState(() {
        _receiptId = (result['temporaryReceiptId'] as num).toInt();
        _code.text = result['receiptCode']?.toString() ?? _code.text;
      });
      context.go('/company/temporary-receipts');
      showTimedSnackBar(context, message: 'บันทึกใบเสร็จรับเงินชั่วคราวสำเร็จ');
    } catch (error) {
      if (mounted) _error('ไม่สามารถบันทึกใบเสร็จรับเงินชั่วคราวได้', error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(padding: padding ?? const EdgeInsets.all(18), child: child),
  );

  InputDecoration _decoration(String label, {bool required = false}) =>
      InputDecoration(labelText: '${required ? '* ' : ''}$label');

  Widget _readonly(String label, TextEditingController controller) => TextField(
    controller: controller,
    readOnly: true,
    decoration: _decoration(label),
  );

  Widget _summaryLine(String label, double value, {bool total = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: total ? FontWeight.w700 : null),
              ),
            ),
            Text(
              _money(value),
              style: TextStyle(
                color: total ? workspaceThemeController.value.primary : null,
                fontSize: total ? 18 : null,
                fontWeight: total ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final sourceRows = _referenceType == 'QUOTATION' ? _quotations : _preOrders;
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
                  final compact = constraints.maxWidth < 780;
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
                                  titleColor: LaooColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _payments.isEmpty ? null : _exportPdf,
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('พิมพ์'),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go('/company/temporary-receipts'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('ยกเลิก'),
                              ),
                              const SizedBox(width: 4),
                              FilledButton.icon(
                                onPressed: _canSave && !_saving ? _save : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'กำลังบันทึก...' : 'บันทึก',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ข้อมูลเอกสารและผู้ชำระเงิน',
                                style: TextStyle(
                                  color: LaooColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 220,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _referenceType,
                                      decoration: _decoration(
                                        'ประเภทเอกสารอ้างอิง',
                                        required: true,
                                      ),
                                      style: const TextStyle(
                                        color: LaooColors.textPrimary,
                                        fontSize: LaooTypography.comboBox,
                                      ),
                                      items: const [
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
                                      onChanged: _changeReferenceType,
                                    ),
                                  ),
                                  if (_referenceType != 'NONE')
                                    SizedBox(
                                      width: compact
                                          ? constraints.maxWidth
                                          : 330,
                                      child: DropdownButtonFormField<int>(
                                        key: ValueKey(
                                          '$_referenceType-$_referenceId',
                                        ),
                                        initialValue: _referenceId,
                                        isExpanded: true,
                                        decoration: _decoration(
                                          'เลือกเอกสาร',
                                          required: true,
                                        ),
                                        style: const TextStyle(
                                          color: LaooColors.textPrimary,
                                          fontSize: LaooTypography.comboBox,
                                        ),
                                        items: sourceRows.map((row) {
                                          final id =
                                              (_referenceType == 'QUOTATION'
                                                      ? row['quotationId']
                                                      : row['preOrderId']
                                                            as dynamic)
                                                  as num;
                                          return DropdownMenuItem<int>(
                                            value: id.toInt(),
                                            child: Text(
                                              '${row['code']} | ${row['customerName']} | คงเหลือ ${_money(_number(row['referenceAmount']) - _number(row['previouslyReceivedAmount']))}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _isEdit
                                            ? null
                                            : _selectReference,
                                      ),
                                    ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 210,
                                    child: TextField(
                                      controller: _code,
                                      readOnly: true,
                                      decoration: _decoration('เลขที่เอกสาร'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 190,
                                    child: TextField(
                                      controller: _date,
                                      readOnly: true,
                                      onTap: _pickDate,
                                      decoration:
                                          _decoration(
                                            'วันที่เอกสาร',
                                            required: true,
                                          ).copyWith(
                                            suffixIcon: const Icon(
                                              Icons.calendar_month_outlined,
                                            ),
                                          ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 190,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _status,
                                      decoration: _decoration('สถานะ'),
                                      items: const [
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
                                      onChanged: (value) => setState(
                                        () => _status = value ?? 'DRAFT',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_referenceType == 'NONE')
                                DropdownButtonFormField<int>(
                                  initialValue: _customerId,
                                  isExpanded: true,
                                  decoration: _decoration(
                                    'ลูกค้า',
                                    required: true,
                                  ),
                                  style: const TextStyle(
                                    color: LaooColors.textPrimary,
                                    fontSize: LaooTypography.comboBox,
                                  ),
                                  items: _customers
                                      .map(
                                        (row) => DropdownMenuItem<int>(
                                          value: (row['customerId'] as num)
                                              .toInt(),
                                          child: Text(
                                            '${row['customerCode']} | ${row['customerName']}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _selectCustomer,
                                  validator: (value) =>
                                      value == null ? 'กรุณาเลือกลูกค้า' : null,
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 180,
                                    child: _readonly(
                                      'รหัสลูกค้า',
                                      _customerCode,
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 350,
                                    child: _readonly(
                                      'ชื่อลูกค้า',
                                      _customerName,
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 220,
                                    child: _readonly(
                                      'เลขประจำตัวผู้เสียภาษี',
                                      _taxId,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _address,
                                readOnly: true,
                                maxLines: 2,
                                decoration: _decoration('ที่อยู่ลูกค้า'),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 360,
                                    child: TextField(
                                      controller: _contact,
                                      decoration: _decoration('ชื่อผู้ติดต่อ'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 360,
                                    child: TextFormField(
                                      controller: _receivedFrom,
                                      decoration: _decoration(
                                        'รับเงินจาก',
                                        required: true,
                                      ),
                                      validator: (value) =>
                                          value?.trim().isEmpty == true
                                          ? 'กรุณาระบุผู้ชำระเงิน'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _surface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'รายการรับเงิน',
                                        style: TextStyle(
                                          color: LaooColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: _canSave
                                          ? () => _editPayment()
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: accent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('เพิ่มรายการ'),
                                    ),
                                  ],
                                ),
                              ),
                              if (_payments.isEmpty)
                                const SizedBox(
                                  height: 110,
                                  child: Center(
                                    child: Text('ยังไม่มีรายการรับเงิน'),
                                  ),
                                )
                              else if (compact)
                                ..._payments.indexed.map((entry) {
                                  final row = entry.$2;
                                  return Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      8,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x10000000),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_methodName(row['paymentMethodCode'])}\n${_money(row['amount'])}',
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _editPayment(entry.$1),
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: accent,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _removePayment(entry.$1),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                              else
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: DataTable(
                                    headingRowColor: WidgetStatePropertyAll(
                                      accent.withValues(alpha: .09),
                                    ),
                                    dividerThickness: .5,
                                    columns: const [
                                      DataColumn(label: Text('ID')),
                                      DataColumn(label: Text('Action')),
                                      DataColumn(label: Text('ช่องทางรับเงิน')),
                                      DataColumn(label: Text('เลขที่อ้างอิง')),
                                      DataColumn(
                                        label: Text('จำนวนเงิน'),
                                        numeric: true,
                                      ),
                                      DataColumn(label: Text('หมายเหตุ')),
                                    ],
                                    rows: _payments.indexed.map((entry) {
                                      final row = entry.$2;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('${entry.$1 + 1}')),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () =>
                                                      _editPayment(entry.$1),
                                                  icon: Icon(
                                                    Icons.edit_outlined,
                                                    color: accent,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () =>
                                                      _removePayment(entry.$1),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _methodName(
                                                row['paymentMethodCode'],
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              row['referenceNo']?.toString() ??
                                                  '-',
                                            ),
                                          ),
                                          DataCell(Text(_money(row['amount']))),
                                          DataCell(
                                            Text(
                                              row['remark']?.toString() ?? '-',
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
                            builder: (context, cardConstraints) {
                              final narrow = cardConstraints.maxWidth < 680;
                              final remark = TextField(
                                controller: _remark,
                                maxLines: 4,
                                decoration: _decoration('หมายเหตุ'),
                              );
                              final summary = Column(
                                children: [
                                  _summaryLine(
                                    'ยอดเอกสารอ้างอิง',
                                    _referenceAmount,
                                  ),
                                  _summaryLine(
                                    'รับเงินก่อนหน้า',
                                    _previouslyReceived,
                                  ),
                                  const Divider(color: LaooColors.border),
                                  _summaryLine(
                                    'รับเงินครั้งนี้',
                                    _receivedAmount,
                                    total: true,
                                  ),
                                  _summaryLine(
                                    'ยอดคงเหลือ',
                                    _balanceAmount,
                                    total: true,
                                  ),
                                ],
                              );
                              return narrow
                                  ? Column(
                                      children: [
                                        remark,
                                        const SizedBox(height: 16),
                                        summary,
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: remark),
                                        const SizedBox(width: 28),
                                        Expanded(flex: 2, child: summary),
                                      ],
                                    );
                            },
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

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.methods, this.initial});

  final List<Map<String, dynamic>> methods;
  final Map<String, dynamic>? initial;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _method;
  late final TextEditingController _amount;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _reference;
  late final TextEditingController _cheque;
  late final TextEditingController _chequeDate;
  late final TextEditingController _remark;

  @override
  void initState() {
    super.initState();
    final row = widget.initial ?? const <String, dynamic>{};
    _method =
        row['paymentMethodCode']?.toString() ??
        widget.methods.first['code']?.toString();
    _amount = TextEditingController(text: row['amount']?.toString() ?? '');
    _bank = TextEditingController(text: row['bankCode']?.toString() ?? '');
    _account = TextEditingController(
      text: row['bankAccountName']?.toString() ?? '',
    );
    _reference = TextEditingController(
      text: row['referenceNo']?.toString() ?? '',
    );
    _cheque = TextEditingController(text: row['chequeNo']?.toString() ?? '');
    _chequeDate = TextEditingController(
      text: row['chequeDate']?.toString().split('T').first ?? '',
    );
    _remark = TextEditingController(text: row['remark']?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _amount,
      _bank,
      _account,
      _reference,
      _cheque,
      _chequeDate,
      _remark,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickChequeDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_chequeDate.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() {
        _chequeDate.text =
            '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: const Row(
        children: [
          Icon(Icons.payments_outlined),
          SizedBox(width: 8),
          Text(
            'รายการรับเงิน',
            style: TextStyle(
              color: LaooColors.textPrimary,
              fontSize: LaooTypography.workspaceCaption,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Divider(color: LaooColors.border),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '* ช่องทางรับเงิน',
                  ),
                  items: widget.methods
                      .map(
                        (row) => DropdownMenuItem<String>(
                          value: row['code']?.toString(),
                          child: Text(row['name']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _method = value),
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกช่องทางรับเงิน' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(labelText: '* จำนวนเงิน'),
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                      ? 'จำนวนเงินต้องมากกว่า 0'
                      : null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _bank,
                        decoration: const InputDecoration(labelText: 'ธนาคาร'),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _account,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อบัญชี',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _reference,
                        decoration: const InputDecoration(
                          labelText: 'เลขที่อ้างอิง',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _cheque,
                        decoration: const InputDecoration(
                          labelText: 'เลขที่เช็ค',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _chequeDate,
                        readOnly: true,
                        onTap: _pickChequeDate,
                        decoration: const InputDecoration(
                          labelText: 'วันที่เช็ค',
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remark,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                ),
                const SizedBox(height: 10),
                const Divider(color: LaooColors.border),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          label: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, <String, dynamic>{
              'paymentMethodCode': _method,
              'amount': double.parse(_amount.text),
              'bankCode': _bank.text.trim(),
              'bankAccountName': _account.text.trim(),
              'referenceNo': _reference.text.trim(),
              'chequeNo': _cheque.text.trim(),
              'chequeDate': _chequeDate.text.trim().isEmpty
                  ? null
                  : _chequeDate.text.trim(),
              'remark': _remark.text.trim(),
            });
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }
}
