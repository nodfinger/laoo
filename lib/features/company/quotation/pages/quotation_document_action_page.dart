import 'dart:convert';

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

class QuotationDocumentActionPage extends StatefulWidget {
  const QuotationDocumentActionPage({this.quotationId, super.key});

  final int? quotationId;

  @override
  State<QuotationDocumentActionPage> createState() =>
      _QuotationDocumentActionPageState();
}

Future<({bool proceed, Uint8List? bytes})> _askQuotationActionSignature(
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

class _QuotationDocumentActionPageState
    extends State<QuotationDocumentActionPage> {
  final _api = QuotationApi();
  final _quoteCode = TextEditingController(text: 'สร้างอัตโนมัติ');
  final _quoteDate = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController(text: '0');
  final _lineDiscount = TextEditingController(text: '0');
  final _validDays = TextEditingController(text: '30');
  final _creditDays = TextEditingController(text: '0');
  final _discountPercent = TextEditingController(text: '0');
  final _vatPercent = TextEditingController(text: '7');
  final _remark = TextEditingController();

  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _creditTypes = const [];
  List<Map<String, dynamic>> _employees = const [];
  List<Map<String, dynamic>> _items = const [];
  final List<_QuotationLine> _lines = [];
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _selectedItem;
  int? _employeeId;
  String? _paymentType;
  DateTime _documentDate = DateTime.now();
  String _discountType = 'N';
  String? _selectedContactKey;
  int? _editingLineIndex;
  bool _showItemImages = true;
  String _menuName = '';
  bool _loading = true;
  bool _saving = false;
  bool _exportingPdf = false;
  int? _quotationId;

  bool get _isEdit => _quotationId != null;

  @override
  void initState() {
    super.initState();
    _quotationId = widget.quotationId;
    _quoteDate.text = _formatDate(_documentDate);
    _resolveMenuName();
    _loadLookup();
  }

  @override
  void dispose() {
    _api.dispose();
    _quoteCode.dispose();
    _quoteDate.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _lineDiscount.dispose();
    _validDays.dispose();
    _creditDays.dispose();
    _discountPercent.dispose();
    _vatPercent.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _resolveMenuName() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: 'companyQuotations',
      fallback: 'ใบเสนอราคา',
    );
    if (mounted) setState(() => _menuName = name);
  }

  Future<void> _loadLookup() async {
    try {
      final data = await _api.lookup();
      _customers = List<Map<String, dynamic>>.from(
        data['customers'] ?? const [],
      );
      _creditTypes = List<Map<String, dynamic>>.from(
        data['creditTypes'] ?? const [],
      );
      _employees = List<Map<String, dynamic>>.from(
        data['employees'] ?? const [],
      );
      _items = List<Map<String, dynamic>>.from(data['items'] ?? const []);
      for (final employee in _employees) {
        if (employee['isCurrent'] == true) {
          _employeeId = (employee['employeeId'] as num).toInt();
          break;
        }
      }
      if (_quotationId != null) {
        await _loadDocument(_quotationId!);
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถโหลดข้อมูลใบเสนอราคาได้\nรายละเอียด: $error\nกรุณาตรวจสอบการเชื่อมต่อ API แล้วลองใหม่',
          error: true,
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDocument(int quotationId) async {
    final result = await _api.get(quotationId);
    final header = Map<String, dynamic>.from(result['header'] as Map);
    final detailRows = List<Map<String, dynamic>>.from(
      result['items'] as List? ?? const [],
    );
    final customerId = (header['customerId'] as num?)?.toInt();
    final customer = _customers
        .where((row) => (row['customerId'] as num?)?.toInt() == customerId)
        .firstOrNull;
    final employeeId = (header['salespersonEmployeeId'] as num?)?.toInt();
    final quoteDate = DateTime.tryParse('${header['quoteDate'] ?? ''}');
    if (!mounted) return;
    setState(() {
      _quotationId = quotationId;
      _quoteCode.text = '${header['quoteCode'] ?? ''}';
      if (quoteDate != null) {
        _documentDate = quoteDate;
        _quoteDate.text = _formatDate(quoteDate);
      }
      _customer = customer;
      _employeeId =
          _employees.any(
            (row) => (row['employeeId'] as num?)?.toInt() == employeeId,
          )
          ? employeeId
          : _employeeId;
      _paymentType = header['paymentType']?.toString();
      _validDays.text = '${header['validDays'] ?? 0}';
      _creditDays.text = '${header['creditDays'] ?? 0}';
      _discountPercent.text = '${header['discountPercent'] ?? 0}';
      _vatPercent.text = '${header['taxPercent'] ?? header['vatPercent'] ?? 0}';
      _remark.text = '${header['remark'] ?? ''}';
      final contactName = header['contactName']?.toString().trim() ?? '';
      _selectedContactKey = _customerContacts
          .where((contact) => contact.name == contactName)
          .firstOrNull
          ?.key;
      _lines
        ..clear()
        ..addAll(
          detailRows.map((row) {
            final itemId = (row['itemId'] as num).toInt();
            final lookupItem = _items
                .where((item) => (item['itemId'] as num?)?.toInt() == itemId)
                .firstOrNull;
            final type = '${row['discountType'] ?? 'N'}'.toUpperCase();
            final discountValue = type == 'P'
                ? _toDouble(row['discountPercent'])
                : type == 'A'
                ? _toDouble(row['discountAmount'])
                : 0.0;
            return _QuotationLine(
              itemId: itemId,
              itemCode: '${row['itemCode'] ?? ''}',
              itemName: '${row['itemName'] ?? ''}',
              unitCode: '${lookupItem?['unitCode'] ?? row['unitCode'] ?? ''}',
              quantity: _toDouble(row['quantity']),
              unitPrice: _toDouble(row['unitPrice']),
              discountType: type,
              discountValue: discountValue,
              coverImageBase64:
                  lookupItem?['coverImageBase64']?.toString() ??
                  row['coverImageBase64']?.toString(),
            );
          }),
        );
    });
  }

  InputDecoration _dec(String label, {Widget? suffixIcon}) => InputDecoration(
    labelText: label,
    suffixIcon: suffixIcon,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(LaooRadius.xs)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: LaooColors.border),
      borderRadius: BorderRadius.all(Radius.circular(LaooRadius.xs)),
    ),
  );

  Card _card(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: LaooColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      side: BorderSide.none,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _menuName.isEmpty ? 'ใบเสนอราคา' : _menuName,
      activeMenu: 'companyQuotations',
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCaptionCard(accent),
                  const SizedBox(height: 8),
                  _buildDocumentHeaderCard(accent),
                  const SizedBox(height: 8),
                  _buildItemsCard(accent),
                  const SizedBox(height: 8),
                  _buildSummaryCard(accent),
                ],
              ),
      ),
    );
  }

  Widget _buildCaptionCard(Color accent) => _card(
    LayoutBuilder(
      builder: (context, constraints) {
        final title = WorkspacePageTitle(
          title:
              '${_menuName.isEmpty ? 'ใบเสนอราคา' : _menuName} > ${_isEdit ? 'แก้ไข' : 'เพิ่ม'}',
          favoriteKey: 'companyQuotations',
          titleColor: LaooColors.textPrimary,
          titleFontSize: LaooTypography.pageTitle,
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: _exportingPdf ? null : _exportPdf,
              icon: _exportingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: const Text('พิมพ์'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => context.go('/company/quotations'),
              icon: const Icon(Icons.close),
              label: const Text('ยกเลิก'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            actions,
          ],
        );
      },
    ),
  );

  Widget _buildDocumentHeaderCard(Color accent) => _card(
    LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final customerCode = _customer?['cusCode']?.toString() ?? '';
        final customerName = _customer?['cusName']?.toString() ?? '';
        final address = _customer?['address']?.toString() ?? '';
        final taxId = _customer?['taxId']?.toString() ?? '';
        final contacts = _customerContacts;
        final selectedContact = contacts
            .where((contact) => contact.key == _selectedContactKey)
            .firstOrNull;
        final contactEmail = selectedContact?.email.trim() ?? '';
        final email = contactEmail.isNotEmpty
            ? contactEmail
            : _customer?['email']?.toString() ?? '';

        final customerField = TextFormField(
          key: ValueKey('customer-code-$customerCode'),
          readOnly: true,
          initialValue: customerCode,
          decoration: _dec(
            '* รหัสลูกค้า',
            suffixIcon: IconButton(
              tooltip: 'ค้นหาลูกค้า',
              onPressed: _showCustomerLookup,
              icon: Icon(Icons.search, color: accent),
            ),
          ),
          onTap: _showCustomerLookup,
        );
        final numberField = TextField(
          controller: _quoteCode,
          readOnly: true,
          textAlign: TextAlign.right,
          decoration: _dec('เลขที่เอกสาร'),
        );
        final nameField = TextFormField(
          key: ValueKey('customer-name-$customerName'),
          readOnly: true,
          initialValue: customerName,
          decoration: _dec('ชื่อลูกค้า'),
        );
        final dateField = TextField(
          controller: _quoteDate,
          readOnly: true,
          textAlign: TextAlign.right,
          decoration: _dec(
            'วันที่เอกสาร',
            suffixIcon: IconButton(
              tooltip: 'เลือกวันที่',
              onPressed: _selectDate,
              icon: Icon(Icons.calendar_month_outlined, color: accent),
            ),
          ),
          onTap: _selectDate,
        );
        final validDaysField = TextField(
          controller: _validDays,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          decoration: _dec('ยืนราคา (วัน)'),
        );
        final creditTypeField = DropdownButtonFormField<String>(
          initialValue:
              _creditTypes.any(
                (type) => type['code']?.toString() == _paymentType,
              )
              ? _paymentType
              : null,
          style: const TextStyle(fontSize: 12, color: LaooColors.textPrimary),
          decoration: _dec('ประเภทเครดิต'),
          items: _creditTypes
              .map(
                (type) => DropdownMenuItem<String>(
                  value: type['code']?.toString(),
                  child: Text(type['name']?.toString() ?? ''),
                ),
              )
              .toList(),
          onChanged: _creditTypes.isEmpty
              ? null
              : (value) => setState(() => _paymentType = value),
        );
        final creditDaysField = TextField(
          controller: _creditDays,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          decoration: _dec('จำนวนวันเครดิต'),
        );
        final addressField = TextFormField(
          key: ValueKey('customer-address-$address'),
          readOnly: true,
          maxLines: 2,
          initialValue: address,
          decoration: _dec('ที่อยู่ลูกค้า'),
        );
        final emailField = TextFormField(
          key: ValueKey('customer-email-${selectedContact?.key}-$email'),
          readOnly: true,
          initialValue: email,
          decoration: _dec('Email'),
        );
        final taxIdField = TextFormField(
          key: ValueKey('customer-tax-id-$taxId'),
          readOnly: true,
          initialValue: taxId,
          decoration: _dec('เลขประจำตัวผู้เสียภาษี'),
        );
        final contactField = DropdownButtonFormField<String>(
          key: ValueKey(
            'customer-contact-${_customer?['customerId']}-$_selectedContactKey',
          ),
          initialValue: selectedContact?.key,
          decoration: _dec('ชื่อผู้ติดต่อ'),
          items: contacts
              .map(
                (contact) => DropdownMenuItem<String>(
                  value: contact.key,
                  child: Text(contact.name),
                ),
              )
              .toList(),
          onChanged: contacts.isEmpty
              ? null
              : (value) => setState(() => _selectedContactKey = value),
        );
        final phoneField = TextFormField(
          key: ValueKey('customer-phone-${selectedContact?.phone ?? ''}'),
          readOnly: true,
          initialValue: selectedContact?.phone ?? '',
          decoration: _dec('เบอร์โทรผู้ติดต่อ'),
        );
        final dateAndValidDays = Row(
          children: [
            Expanded(flex: 2, child: dateField),
            const SizedBox(width: 12),
            Expanded(child: validDaysField),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Icons.description_outlined, 'ส่วนหัวเอกสาร', accent),
            const SizedBox(height: 12),
            if (compact) ...[
              customerField,
              const SizedBox(height: 12),
              numberField,
              const SizedBox(height: 12),
              nameField,
              const SizedBox(height: 12),
              dateAndValidDays,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: creditTypeField),
                  const SizedBox(width: 12),
                  Expanded(child: creditDaysField),
                ],
              ),
              const SizedBox(height: 12),
              addressField,
              const SizedBox(height: 12),
              taxIdField,
              const SizedBox(height: 12),
              contactField,
              const SizedBox(height: 12),
              phoneField,
              const SizedBox(height: 12),
              emailField,
              const SizedBox(height: 12),
              _salespersonField(),
            ] else ...[
              Row(
                children: [
                  Expanded(flex: 3, child: customerField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: numberField),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 3, child: nameField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: dateAndValidDays),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 3, child: creditTypeField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: creditDaysField),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: addressField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _salespersonField()),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: taxIdField),
                  const SizedBox(width: 8),
                  Expanded(child: contactField),
                  const SizedBox(width: 8),
                  Expanded(child: phoneField),
                  const SizedBox(width: 8),
                  Expanded(child: emailField),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );

  List<_QuotationContact> get _customerContacts {
    final customer = _customer;
    if (customer == null) return const [];
    final contacts = <_QuotationContact>[];
    final name1 = customer['contactName1']?.toString().trim() ?? '';
    final name2 = customer['contactName2']?.toString().trim() ?? '';
    if (name1.isNotEmpty) {
      contacts.add(
        _QuotationContact(
          key: '1',
          name: name1,
          phone: customer['contactPhone1']?.toString() ?? '',
          email: customer['contactEmail1']?.toString() ?? '',
        ),
      );
    }
    if (name2.isNotEmpty) {
      contacts.add(
        _QuotationContact(
          key: '2',
          name: name2,
          phone: customer['contactPhone2']?.toString() ?? '',
          email: customer['contactEmail2']?.toString() ?? '',
        ),
      );
    }
    return contacts;
  }

  Widget _salespersonField() => DropdownButtonFormField<int>(
    initialValue: _employeeId,
    decoration: _dec('* ผู้เสนอราคา'),
    items: _employees
        .map(
          (employee) => DropdownMenuItem<int>(
            value: (employee['employeeId'] as num).toInt(),
            child: Text(
              '${employee['fullName']}${employee['nickName'] == null ? '' : ' | ${employee['nickName']}'}',
            ),
          ),
        )
        .toList(),
    onChanged: (value) => setState(() => _employeeId = value),
  );

  Widget _buildItemsCard(Color accent) => _card(
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
            const Text('แสดงรูปสินค้า'),
            const SizedBox(width: 8),
            Switch(
              value: _showItemImages,
              activeThumbColor: accent,
              onChanged: (value) => setState(() => _showItemImages = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final itemCode = _selectedItem?['itemCode']?.toString() ?? '';
            final itemField = TextFormField(
              key: ValueKey('item-code-$itemCode'),
              readOnly: true,
              initialValue: itemCode,
              decoration: _dec(
                'รหัสสินค้า',
                suffixIcon: IconButton(
                  tooltip: 'ค้นหาสินค้า',
                  onPressed: _showItemLookup,
                  icon: Icon(Icons.search, color: accent),
                ),
              ),
              onTap: _showItemLookup,
            );
            final quantityField = TextField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _dec('จำนวน'),
            );
            final priceField = TextField(
              controller: _unitPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _dec('ราคา'),
            );
            final discountTypeField = DropdownButtonFormField<String>(
              initialValue: _discountType,
              style: const TextStyle(
                fontSize: 12,
                color: LaooColors.textPrimary,
              ),
              decoration: _dec('ลดแบบ'),
              items: const [
                DropdownMenuItem(
                  value: 'N',
                  child: Text('ไม่ลด', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'P',
                  child: Text(
                    'เปอร์เซ็นต์ (%)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                DropdownMenuItem(
                  value: 'A',
                  child: Text(
                    'จำนวนเงิน (บาท)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _discountType = value ?? 'N';
                  _lineDiscount.text = '0';
                });
              },
            );
            final discountField = TextField(
              controller: _lineDiscount,
              readOnly: _discountType == 'N',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              decoration: _dec(
                _discountType == 'P'
                    ? 'ส่วนลด (%)'
                    : _discountType == 'A'
                    ? 'ส่วนลด (บาท)'
                    : 'ส่วนลด',
              ),
            );
            final addButton = FilledButton.icon(
              onPressed: _addLine,
              icon: Icon(
                _editingLineIndex == null ? Icons.add : Icons.save_outlined,
              ),
              label: Text(
                _editingLineIndex == null ? 'เพิ่มรายการ' : 'บันทึกแก้ไข',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
            );
            if (compact) {
              return Column(
                children: [
                  itemField,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 12),
                      Expanded(child: priceField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: discountTypeField),
                      const SizedBox(width: 12),
                      Expanded(child: discountField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: addButton),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 4, child: itemField),
                const SizedBox(width: 12),
                Expanded(child: quantityField),
                const SizedBox(width: 12),
                Expanded(child: priceField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: discountTypeField),
                const SizedBox(width: 12),
                Expanded(child: discountField),
                const SizedBox(width: 12),
                addButton,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _buildItemTable(accent),
      ],
    ),
  );

  Widget _buildItemTable(Color accent) => SizedBox(
    width: double.infinity,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(accent.withValues(alpha: .10)),
        headingTextStyle: TextStyle(
          color: accent,
          fontSize: LaooTypography.tableHeader,
          fontWeight: FontWeight.w700,
        ),
        columns: [
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('Action')),
          if (_showItemImages) const DataColumn(label: Text('รูปสินค้า')),
          const DataColumn(label: Text('รหัสสินค้า')),
          const DataColumn(label: Text('ชื่อสินค้า')),
          const DataColumn(label: Text('จำนวน'), numeric: true),
          const DataColumn(label: Text('หน่วยนับ')),
          const DataColumn(label: Text('ราคา'), numeric: true),
          const DataColumn(label: Text('ลดแบบ')),
          const DataColumn(label: Text('ส่วนลด'), numeric: true),
          const DataColumn(label: Text('รวมเงิน'), numeric: true),
        ],
        rows: List.generate(_lines.length, (index) {
          final line = _lines[index];
          return DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'แก้ไขรายการ',
                      onPressed: () => _editLine(index),
                      icon: Icon(Icons.edit_outlined, color: accent),
                    ),
                    IconButton(
                      tooltip: 'ลบรายการ',
                      onPressed: () => _confirmDeleteLine(index),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: LaooColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showItemImages)
                DataCell(_productImage(line.coverImageBase64, size: 42)),
              DataCell(Text(line.itemCode)),
              DataCell(Text(line.itemName)),
              DataCell(Text(_number(line.quantity))),
              DataCell(Text(line.unitCode)),
              DataCell(Text(_money(line.unitPrice))),
              DataCell(Text(line.discountTypeName)),
              DataCell(Text(line.discountDisplay)),
              DataCell(Text(_money(line.amount))),
            ],
          );
        }),
      ),
    ),
  );

  Widget _buildSummaryCard(Color accent) => _card(
    LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final summary = _summary;
        final remark = TextField(
          controller: _remark,
          maxLines: 4,
          decoration: _dec('หมายเหตุ'),
        );
        final totals = SizedBox(
          width: compact ? double.infinity : 390,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: compact ? double.infinity : 160,
                  child: const Divider(color: LaooColors.border),
                ),
              ),
              const SizedBox(height: 8),
              _amountRow('รวมเงิน', summary.total),
              const SizedBox(height: 8),
              _numberAndAmountRow('ส่วนลด', _discountPercent, summary.discount),
              const SizedBox(height: 8),
              _amountRow('รวมเงินหลังหักส่วนลด', summary.afterDiscount),
              const SizedBox(height: 8),
              _numberAndAmountRow('ภาษี', _vatPercent, summary.tax),
              const Divider(height: 20, color: LaooColors.border),
              _amountRow(
                'รวมเงินสุทธิ',
                summary.net,
                emphasized: true,
                accent: accent,
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _sectionTitle(
                Icons.calculate_outlined,
                'สรุปยอดเงิน',
                accent,
              ),
            ),
            const SizedBox(height: 12),
            if (compact) ...[
              remark,
              const SizedBox(height: 12),
              totals,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: remark),
                  const SizedBox(width: 24),
                  totals,
                ],
              ),
          ],
        );
      },
    ),
  );

  Widget _sectionTitle(IconData icon, String title, Color accent) => Row(
    children: [
      Icon(icon, color: accent),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: LaooColors.textPrimary,
          fontSize: LaooTypography.sectionTitle,
          fontWeight: LaooTypography.emphasizedWeight,
        ),
      ),
    ],
  );

  Widget _amountRow(
    String label,
    double amount, {
    bool emphasized = false,
    Color? accent,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: emphasized
                ? LaooTypography.emphasizedWeight
                : LaooTypography.normalWeight,
          ),
        ),
      ),
      Text(
        _money(amount),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: emphasized ? accent : LaooColors.textPrimary,
          fontSize: emphasized
              ? LaooTypography.sectionTitle
              : LaooTypography.body,
          fontWeight: emphasized
              ? LaooTypography.emphasizedWeight
              : LaooTypography.normalWeight,
        ),
      ),
    ],
  );

  Widget _numberAndAmountRow(
    String label,
    TextEditingController controller,
    double amount,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      SizedBox(
        width: 88,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _dec('%'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 110,
        child: Text(_money(amount), textAlign: TextAlign.right),
      ),
    ],
  );

  Future<void> _showCustomerLookup() async {
    final selected = await _showLookup(
      title: 'ค้นหาลูกค้า',
      icon: Icons.people_outline,
      rows: _customers,
      searchText: (row) =>
          '${row['cusCode']} ${row['cusName']} ${row['shortCode'] ?? ''}',
      titleText: (row) => '${row['cusCode']} - ${row['cusName']}',
      subtitleText: (row) => row['address']?.toString() ?? '',
    );
    if (selected != null && mounted) {
      setState(() {
        _customer = selected;
        final customerPaymentType = selected['paymentType']?.toString().trim();
        final customerCreditDays = selected['creditDays'];
        final matchingCreditType =
            _creditTypes.any(
              (type) => type['code']?.toString() == customerPaymentType,
            )
            ? customerPaymentType
            : (_creditTypes.isEmpty
                  ? null
                  : _creditTypes.first['code']?.toString());
        _paymentType = matchingCreditType;
        _creditDays.text = customerCreditDays == null
            ? '0'
            : customerCreditDays.toString();
        final firstName = selected['contactName1']?.toString().trim() ?? '';
        final secondName = selected['contactName2']?.toString().trim() ?? '';
        _selectedContactKey = firstName.isNotEmpty
            ? '1'
            : secondName.isNotEmpty
            ? '2'
            : null;
      });
    }
  }

  Future<void> _showItemLookup() async {
    final selected = await _showLookup(
      title: 'ค้นหาสินค้า',
      icon: Icons.inventory_2_outlined,
      rows: _items,
      searchText: (row) => '${row['itemCode']} ${row['itemName']}',
      titleText: (row) => '${row['itemCode']} - ${row['itemName']}',
      subtitleText: (row) =>
          'หน่วย ${row['unitCode'] ?? '-'} | ราคา ${_money(_toDouble(row['unitPrice']))}',
      leading: _showItemImages
          ? (row) => _productImage(row['coverImageBase64'], size: 44)
          : null,
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedItem = selected;
        _unitPrice.text = _toDouble(selected['unitPrice']).toStringAsFixed(2);
      });
    }
  }

  Future<Map<String, dynamic>?> _showLookup({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
    required String Function(Map<String, dynamic>) searchText,
    required String Function(Map<String, dynamic>) titleText,
    required String Function(Map<String, dynamic>) subtitleText,
    Widget Function(Map<String, dynamic>)? leading,
  }) async {
    var query = '';
    final accent = workspaceThemeController.value.primary;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = rows
              .where(
                (row) =>
                    searchText(row).toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: LaooColors.textPrimary,
                    fontSize: LaooTypography.pageTitle,
                    fontWeight: LaooTypography.pageTitleWeight,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              height: 460,
              child: Column(
                children: [
                  const Divider(color: LaooColors.border),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: _dec(
                      'ค้นหา',
                      suffixIcon: Icon(Icons.search, color: accent),
                    ),
                    onChanged: (value) =>
                        setDialogState(() => query = value.trim()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูล'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: LaooColors.border,
                            ),
                            itemBuilder: (context, index) {
                              final row = filtered[index];
                              final subtitle = subtitleText(row);
                              return ListTile(
                                leading: leading?.call(row),
                                title: Text(titleText(row)),
                                subtitle: subtitle.isEmpty
                                    ? null
                                    : Text(subtitle),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: accent,
                                ),
                                onTap: () => Navigator.pop(dialogContext, row),
                              );
                            },
                          ),
                  ),
                  const Divider(color: LaooColors.border),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('ปิด', style: TextStyle(color: accent)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final accent = workspaceThemeController.value.primary;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: accent),
          ),
          child: child!,
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _documentDate = selected;
        _quoteDate.text = _formatDate(selected);
      });
    }
  }

  Widget _productImage(Object? value, {required double size}) {
    final encoded = value?.toString() ?? '';
    if (encoded.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.inventory_2_outlined),
      );
    }
    try {
      final bytes = base64Decode(encoded);
      return InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    } on FormatException {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.broken_image_outlined),
      );
    }
  }

  void _editLine(int index) {
    final line = _lines[index];
    setState(() {
      _editingLineIndex = index;
      _selectedItem = {
        'itemId': line.itemId,
        'itemCode': line.itemCode,
        'itemName': line.itemName,
        'unitCode': line.unitCode,
        'unitPrice': line.unitPrice,
        'coverImageBase64': line.coverImageBase64,
      };
      _quantity.text = _number(line.quantity);
      _unitPrice.text = line.unitPrice.toStringAsFixed(2);
      _discountType = line.discountType;
      _lineDiscount.text = line.discountValue.toStringAsFixed(2);
    });
  }

  Future<void> _confirmDeleteLine(int index) async {
    final line = _lines[index];
    final accent = workspaceThemeController.value.primary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: accent),
            ),
            const SizedBox(width: 12),
            Text(
              'ยืนยันการลบข้อมูล',
              style: TextStyle(
                color: accent,
                fontSize: 20,
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
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ ${line.itemCode} - ${line.itemName} หรือไม่?',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
            const SizedBox(height: 12),
            const Divider(color: LaooColors.border),
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
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _lines.removeAt(index);
      if (_editingLineIndex == index) {
        _resetLineEditor();
      } else if (_editingLineIndex != null && _editingLineIndex! > index) {
        _editingLineIndex = _editingLineIndex! - 1;
      }
    });
  }

  void _resetLineEditor() {
    _editingLineIndex = null;
    _selectedItem = null;
    _quantity.text = '1';
    _unitPrice.text = '0';
    _discountType = 'N';
    _lineDiscount.text = '0';
  }

  void _addLine() {
    final item = _selectedItem;
    final quantity = double.tryParse(_quantity.text.trim());
    final unitPrice = double.tryParse(_unitPrice.text.trim());
    final discountValue = double.tryParse(
      _lineDiscount.text.trim().replaceAll(',', ''),
    );
    if (item == null ||
        quantity == null ||
        quantity <= 0 ||
        unitPrice == null ||
        unitPrice < 0 ||
        discountValue == null ||
        discountValue < 0) {
      showTimedSnackBar(
        context,
        message:
            'ไม่สามารถเพิ่มรายการสินค้าได้\nรายละเอียด: กรุณาเลือกสินค้าและระบุจำนวน/ราคาให้ถูกต้อง',
        error: true,
      );
      return;
    }
    final beforeDiscount = quantity * unitPrice;
    if ((_discountType == 'P' && discountValue > 100) ||
        (_discountType == 'A' && discountValue > beforeDiscount)) {
      showTimedSnackBar(
        context,
        message: _discountType == 'P'
            ? 'ไม่สามารถเพิ่มรายการสินค้าได้\nรายละเอียด: ส่วนลดเปอร์เซ็นต์ต้องไม่เกิน 100%'
            : 'ไม่สามารถเพิ่มรายการสินค้าได้\nรายละเอียด: ส่วนลดจำนวนเงินต้องไม่เกินยอดก่อนส่วนลด ${_money(beforeDiscount)} บาท',
        error: true,
      );
      return;
    }
    setState(() {
      final editedLine = _QuotationLine(
        itemId: (item['itemId'] as num).toInt(),
        itemCode: item['itemCode']?.toString() ?? '',
        itemName: item['itemName']?.toString() ?? '',
        unitCode: item['unitCode']?.toString() ?? '',
        quantity: quantity,
        unitPrice: unitPrice,
        discountType: _discountType,
        discountValue: _discountType == 'N' ? 0 : discountValue,
        coverImageBase64: item['coverImageBase64']?.toString(),
      );
      if (_editingLineIndex == null) {
        _lines.add(editedLine);
      } else {
        _lines[_editingLineIndex!] = editedLine;
      }
      _resetLineEditor();
    });
  }

  Future<void> _exportPdf() async {
    if (_customer == null || _lines.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ยังพิมพ์ใบเสนอราคาไม่ได้\nรายละเอียด: กรุณาเลือกลูกค้าและเพิ่มรายการสินค้าอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }

    final signature = await _askQuotationActionSignature(context);
    if (!signature.proceed) return;

    setState(() => _exportingPdf = true);
    try {
      final setup =
          companySetupController.current ?? await companySetupController.load();
      final contact = _customerContacts
          .where((value) => value.key == _selectedContactKey)
          .firstOrNull;
      final employee = _employees
          .where(
            (value) => (value['employeeId'] as num?)?.toInt() == _employeeId,
          )
          .firstOrNull;
      final creditType = _creditTypes
          .where((value) => '${value['code'] ?? ''}' == _paymentType)
          .firstOrNull;
      final sessionName = appAuthController.session?.displayName?.trim();
      final salespersonName = '${employee?['fullName'] ?? ''}'.trim().isNotEmpty
          ? '${employee?['fullName']}'
          : (sessionName?.isNotEmpty == true ? sessionName! : '-');
      final items = _lines
          .map(
            (line) => <String, dynamic>{
              'itemCode': line.itemCode,
              'itemName': line.itemName,
              'unitName': line.unitCode,
              'quantity': line.quantity,
              'unitPrice': line.unitPrice,
              'discountType': line.discountType,
              'discountValue': line.discountValue,
              'discountPercent': line.discountPercent,
              'discountAmount': line.discountAmount,
            },
          )
          .toList();

      await QuotationPdfService.export(
        documentCode: _quoteCode.text,
        documentDate: _documentDate,
        companyPhone: setup.telephone ?? '',
        companyEmail: setup.email ?? '',
        customerCode: '${_customer?['cusCode'] ?? ''}',
        customerName: '${_customer?['cusName'] ?? ''}',
        customerAddress: '${_customer?['address'] ?? ''}',
        customerTaxId: '${_customer?['taxId'] ?? ''}',
        contactName: contact?.name ?? '',
        contactPhone: contact?.phone ?? '',
        contactEmail: contact?.email ?? '${_customer?['email'] ?? ''}',
        salespersonName: salespersonName,
        validDays: int.tryParse(_validDays.text) ?? 0,
        paymentType: '${creditType?['name'] ?? _paymentType ?? ''}',
        creditDays: int.tryParse(_creditDays.text) ?? 0,
        remark: _remark.text,
        items: items,
        discountPercent: _toDouble(_discountPercent.text),
        vatPercent: _toDouble(_vatPercent.text),
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
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _save() async {
    if (_customer == null || _employeeId == null || _lines.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'ไม่สามารถบันทึกใบเสนอราคาได้\nรายละเอียด: กรุณาเลือกลูกค้า ผู้เสนอราคา และเพิ่มสินค้าอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    final validDays = int.tryParse(_validDays.text.trim());
    if (validDays == null || validDays < 0) {
      showTimedSnackBar(
        context,
        message:
            'ไม่สามารถบันทึกใบเสนอราคาได้\nรายละเอียด: กรุณาระบุจำนวนวันยืนราคาเป็นตัวเลขตั้งแต่ 0 ขึ้นไป',
        error: true,
      );
      return;
    }
    final creditDays = int.tryParse(_creditDays.text.trim());
    if (creditDays == null || creditDays < 0) {
      showTimedSnackBar(
        context,
        message:
            'ไม่สามารถบันทึกใบเสนอราคาได้\nรายละเอียด: จำนวนวันเครดิตต้องเป็นตัวเลขตั้งแต่ 0 ขึ้นไป',
        error: true,
      );
      return;
    }
    final selectedContact = _customerContacts
        .where((contact) => contact.key == _selectedContactKey)
        .firstOrNull;
    final summary = _summary;
    final editing = _isEdit;
    setState(() => _saving = true);
    try {
      final request = <String, dynamic>{
        'customerId': (_customer!['customerId'] as num).toInt(),
        'quoteDate': _documentDate.toIso8601String(),
        'salespersonEmployeeId': _employeeId,
        'contactName': selectedContact?.name,
        'validDays': validDays,
        'paymentType': _paymentType,
        'creditDays': creditDays,
        'vatPercent': _toDouble(_vatPercent.text),
        'totalAmount': summary.total,
        'discountPercent': _toDouble(_discountPercent.text),
        'discountAmount': summary.discount,
        'amountAfterDiscount': summary.afterDiscount,
        'taxPercent': _toDouble(_vatPercent.text),
        'taxAmount': summary.tax,
        'netAmount': summary.net,
        'remark': _remark.text.trim(),
        'items': _lines
            .map(
              (line) => {
                'itemId': line.itemId,
                'quantity': line.quantity,
                'unitPrice': line.unitPrice,
                'discountType': line.discountType,
                'discountValue': line.discountValue,
                'discountPercent': line.discountPercent,
                'discountAmount': line.discountAmount,
              },
            )
            .toList(),
      };
      final result = editing
          ? await _api.update(_quotationId!, request)
          : await _api.create(request);
      if (mounted) {
        _quotationId = (result['quotationId'] as num?)?.toInt() ?? _quotationId;
        _quoteCode.text = result['quoteCode']?.toString() ?? _quoteCode.text;
        showTimedSnackBar(
          context,
          message: editing
              ? 'บันทึกการแก้ไขใบเสนอราคาสำเร็จ'
              : 'บันทึกใบเสนอราคาสำเร็จ',
        );
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถบันทึกใบเสนอราคาได้\nรายละเอียด: $error\nกรุณาตรวจสอบข้อมูลและลองใหม่',
          error: true,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  _QuotationSummary get _summary {
    final total = _lines.fold<double>(0, (sum, line) => sum + line.amount);
    final discountPercent = _toDouble(_discountPercent.text);
    final discount = total * discountPercent / 100;
    final afterDiscount = total - discount;
    final vatPercent = _toDouble(_vatPercent.text);
    final tax = afterDiscount * vatPercent / 100;
    return _QuotationSummary(
      total: total,
      discount: discount,
      afterDiscount: afterDiscount,
      tax: tax,
      net: afterDiscount + tax,
    );
  }

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
  String _money(double value) => value
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  String _number(double value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : '$value';
  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _QuotationLine {
  const _QuotationLine({
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.unitCode,
    required this.quantity,
    required this.unitPrice,
    required this.discountType,
    required this.discountValue,
    this.coverImageBase64,
  });

  final int itemId;
  final String itemCode;
  final String itemName;
  final String unitCode;
  final double quantity;
  final double unitPrice;
  final String discountType;
  final double discountValue;
  final String? coverImageBase64;

  double get beforeDiscount => quantity * unitPrice;
  double get discountPercent => discountType == 'P'
      ? discountValue
      : beforeDiscount == 0
      ? 0
      : discountAmount * 100 / beforeDiscount;
  double get discountAmount => discountType == 'P'
      ? beforeDiscount * discountValue / 100
      : discountType == 'A'
      ? discountValue
      : 0;
  double get amount => beforeDiscount - discountAmount;
  String get discountTypeName => switch (discountType) {
    'P' => 'เปอร์เซ็นต์',
    'A' => 'จำนวนเงิน',
    _ => 'ไม่ลด',
  };
  String get discountDisplay => switch (discountType) {
    'P' => '${discountValue.toStringAsFixed(2)}%',
    'A' => discountAmount.toStringAsFixed(2),
    _ => '0.00',
  };
}

class _QuotationContact {
  const _QuotationContact({
    required this.key,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String key;
  final String name;
  final String phone;
  final String email;
}

class _QuotationSummary {
  const _QuotationSummary({
    required this.total,
    required this.discount,
    required this.afterDiscount,
    required this.tax,
    required this.net,
  });

  final double total;
  final double discount;
  final double afterDiscount;
  final double tax;
  final double net;
}
