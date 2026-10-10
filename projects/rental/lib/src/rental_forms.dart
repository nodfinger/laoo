import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'rental_host.dart';
import 'rental_receipt_pdf.dart';

typedef _Row = Map<String, dynamic>;
_Row _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<_Row> _rows(dynamic v) => v is List ? v.map(_map).toList() : <_Row>[];

String _requestKey() => List<int>.generate(
  16,
  (_) => Random.secure().nextInt(256),
).map((v) => v.toRadixString(16).padLeft(2, '0')).join();

InputDecoration rentalField(LaooWorkspaceUiTokens t, String label) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.radius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    border: border(t.borderColor),
    enabledBorder: border(t.borderColor),
    disabledBorder: border(t.borderColor),
    focusedBorder: border(t.primaryColor),
    errorBorder: border(ThemeData().colorScheme.error),
    focusedErrorBorder: border(ThemeData().colorScheme.error),
  );
}

class RentalActionForm extends StatefulWidget {
  const RentalActionForm({
    super.key,
    required this.menuCode,
    required this.mode,
    required this.title,
    required this.options,
    required this.api,
    required this.tokens,
    this.action,
    this.iconName,
    this.row,
    this.settings = const {},
  });
  final String menuCode, mode, title;
  final String? action, iconName;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> settings, options;
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;

  @override
  State<RentalActionForm> createState() => _RentalActionFormState();
}

class _RentalActionFormState extends State<RentalActionForm> {
  static const base = '/api/company/rental';
  final formKey = GlobalKey<FormState>();
  final text = <String, TextEditingController>{};
  final staffSignKey = GlobalKey<RentalSignaturePadState>();
  final customerSignKey = GlobalKey<RentalSignaturePadState>();
  final photoIds = <int, int>{};
  final serialIds = <int, List<int>>{};
  final serialFields = <int, TextEditingController>{};
  final returnFields = <int, Map<String, TextEditingController>>{};
  final returnConditions = <int, String>{};
  _Row details = {}, settlement = {};
  List<_Row> available = [], detailLines = [], existingAttachments = [];
  final bookingLines = <int, int>{};
  int? branchId,
      customerId,
      rentalItemId,
      warehouseId,
      staffSignId,
      customerSignId;
  String rateUnit = 'DAY', paymentKind = 'RENT', paymentMethod = 'CASH';
  String refundMethod = 'CASH', transferDirection = 'TO_RENTAL';
  bool requireSerial = false, active = true, saving = false, loading = false;
  String? error;

  String get action => widget.action ?? widget.mode;
  int? get bookingId => (widget.row?['id'] as num?)?.toInt();
  bool get isCreateBooking => widget.menuCode == '60004' && action == 'create';
  bool get isHandover => action == 'handover';
  bool get isReturn => action == 'return';
  bool get isFileFlow => isHandover || isReturn;

  @override
  void initState() {
    super.initState();
    final row = widget.row ?? <String, dynamic>{};
    for (final name in const [
      'rentalRate',
      'depositAmount',
      'bookingHoldHours',
      'cancelBeforeHours',
      'quantity',
      'amount',
      'referenceNo',
      'reason',
      'startDate',
      'startTime',
      'endDate',
      'endTime',
      'serialNo',
      'approvedDeduction',
      'damageAmount',
      'remark',
      'otherWarehouseId',
      'transferQuantity',
      'bookingCode',
    ]) {
      text[name] = TextEditingController(text: '${row[name] ?? ''}');
    }
    branchId = (row['branchId'] as num?)?.toInt();
    active = row['isActive'] != false;
    rateUnit = row['rateUnit']?.toString() ?? 'DAY';
    _initDefaults();
    if (isCreateBooking) {
      _loadAvailability();
    } else if (bookingId != null &&
        {
          'payment',
          'handover',
          'return',
          'approve-settlement',
          'refund',
          'detail',
        }.contains(action)) {
      _loadDetails();
    }
  }

  void _initDefaults() {
    final next = DateTime.now().add(const Duration(days: 1));
    final end = next.add(const Duration(days: 1));
    text['startDate']!.text =
        '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    text['startTime']!.text = '09:00';
    text['endDate']!.text =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    text['endTime']!.text = '18:00';
    if (widget.mode == 'edit') {
      for (final key in ['rentalRate', 'depositAmount']) {
        text[key]!.text = '${widget.row?[key] ?? ''}';
      }
      active = widget.row?['isActive'] != false;
    }
    final branches = _rows(widget.options['branches']);
    if (branchId == null && branches.length == 1) {
      branchId = (branches.first['id'] as num).toInt();
    }
    if (action == 'transfer') {
      final other = _rows(
        widget.options['warehouses'],
      ).where((w) => w['isRental'] != true);
      if (other.isNotEmpty) warehouseId = (other.first['id'] as num).toInt();
    }
  }

  @override
  void dispose() {
    for (final controller in text.values) {
      controller.dispose();
    }
    for (final controller in serialFields.values) {
      controller.dispose();
    }
    for (final group in returnFields.values) {
      for (final c in group.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    final branches = _rows(widget.options['branches']);
    branchId ??= branches.isEmpty
        ? null
        : (branches.first['id'] as num).toInt();
    if (branchId == null) return;
    setState(() => loading = true);
    try {
      final start = _offsetDate(
        text['startDate']!.text,
        text['startTime']!.text,
      );
      final end = _offsetDate(text['endDate']!.text, text['endTime']!.text);
      available = _rows(
        await widget.api.get(
          '$base/availability',
          query: {'branchId': '$branchId', 'startAt': start, 'endAt': end},
        ),
      );
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = rentalErrorText(e, 'ตรวจสอบของว่าง');
        });
      }
    }
  }

  String _offsetDate(String date, String time) =>
      '${date.trim()}T${time.trim()}:00+07:00';

  Future<void> _loadDetails() async {
    setState(() => loading = true);
    try {
      if (action == 'approve-settlement' || action == 'refund') {
        settlement = _map(
          await widget.api.get('$base/bookings/$bookingId/settlement'),
        );
      }
      if (isFileFlow || action == 'detail' || action == 'payment') {
        final menu = widget.menuCode;
        final response = _map(
          await widget.api.get(
            '$base/bookings/$bookingId',
            query: {'menu': menu},
          ),
        );
        details = response;
        settlement = _map(response['settlement']);
        detailLines = _rows(response['lines']);
        existingAttachments = _rows(response['attachments']);
        for (final line in detailLines) {
          final id =
              (line['BookingLineID'] as num?)?.toInt() ??
              (line['bookingLineId'] as num?)?.toInt();
          if (id == null) continue;
          serialFields[id] = TextEditingController();
          serialIds[id] = [];
          final alreadyReturned = _rows(response['returnLines'])
              .where((r) => ((r['bookingLineId'] as num?)?.toInt() == id))
              .fold<int>(
                0,
                (sum, r) => sum + ((r['quantity'] as num?)?.toInt() ?? 0),
              );
          final quantity =
              ((line['Quantity'] ?? line['quantity']) as num?)?.toInt() ?? 0;
          returnFields[id] = {
            'quantity': TextEditingController(
              text: '${(quantity - alreadyReturned).clamp(0, quantity)}',
            ),
            'damage': TextEditingController(text: '0'),
            'remark': TextEditingController(),
          };
          returnConditions[id] = 'OK';
        }
        if (action == 'payment') _refreshPaymentAmount();
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = rentalErrorText(e, 'เปิดรายละเอียดรายการ');
        });
      }
    }
  }

  int _lineId(_Row row) =>
      ((row['BookingLineID'] ?? row['bookingLineId']) as num).toInt();
  String _lineName(_Row row) =>
      '${row['ItemCodeSnapshot'] ?? row['ItemCode'] ?? row['itemCode'] ?? ''} ${row['ItemNameSnapshot'] ?? row['ItemName'] ?? row['itemName'] ?? ''}'
          .trim();
  int _outstanding(_Row line) {
    final lineId = _lineId(line);
    final returned = _rows(details['returnLines'])
        .where(
          (r) =>
              ((r['bookingLineId'] ?? r['BookingLineID']) as num?)?.toInt() ==
              lineId,
        )
        .fold<int>(
          0,
          (sum, r) =>
              sum + (((r['quantity'] ?? r['Quantity']) as num?)?.toInt() ?? 0),
        );
    return (((line['Quantity'] ?? line['quantity']) as num?)?.toInt() ?? 0) -
        returned;
  }

  void _refreshPaymentAmount() {
    final header = _map(details['header']);
    final paid = _rows(details['payments'])
        .where((row) => row['Kind'] == paymentKind)
        .fold<double>(
          0,
          (sum, row) => sum + ((row['Amount'] as num?)?.toDouble() ?? 0),
        );
    final total = paymentKind == 'RENT'
        ? ((header['TotalRent'] as num?)?.toDouble() ?? 0)
        : paymentKind == 'DEPOSIT'
        ? ((header['TotalDeposit'] as num?)?.toDouble() ?? 0)
        : ((settlement['AdditionalDue'] as num?)?.toDouble() ??
              (settlement['additionalDue'] as num?)?.toDouble() ??
              0);
    text['amount']!.text = (total - paid).clamp(0, total).toStringAsFixed(2);
  }

  String get _formTitle => switch (action) {
    'create' => widget.menuCode == '60002' ? 'เพิ่มทะเบียนของเช่า' : 'จองเช่า',
    'edit' => 'แก้ไขราคาเช่า',
    'transfer' => 'โอนสต๊อกของเช่า',
    'payment' => 'รับค่าเช่าและมัดจำ',
    'handover' => 'ส่งมอบของเช่า',
    'return' => 'รับคืนและตรวจสภาพ',
    'approve-settlement' => 'อนุมัติยอดหัก',
    'refund' => 'คืนมัดจำ',
    'cancel' => 'ยกเลิกการจอง',
    'detail' => 'รายละเอียดการเช่า',
    _ => widget.title,
  };

  Future<void> _save() async {
    if (saving ||
        (formKey.currentState != null && !formKey.currentState!.validate())) {
      return;
    }
    if (isCreateBooking && bookingLines.isEmpty) {
      setState(() => error = 'เลือกของเช่าอย่างน้อย 1 รายการ');
      return;
    }
    if (isCreateBooking && (branchId == null || customerId == null)) {
      setState(() => error = 'เลือกสาขาและลูกค้าก่อนบันทึก');
      return;
    }
    if (action == 'create' &&
        widget.menuCode == '60002' &&
        (branchId == null || rentalItemId == null || warehouseId == null)) {
      setState(() => error = 'เลือกสาขา สินค้า และคลังเช่าให้ครบ');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      switch (action) {
        case 'create' when widget.menuCode == '60002':
          await widget.api.post(
            '$base/items',
            body: {
              'branchId': branchId,
              'itemId': (rentalItemId),
              'warehouseId': warehouseId,
              'rateUnit': rateUnit,
              'rentalRate': _decimal('rentalRate'),
              'depositAmount': _decimal('depositAmount'),
              'requireSerial': requireSerial,
            },
          );
          break;
        case 'edit':
          await widget.api.put(
            '$base/items/${widget.row?['id']}',
            body: {
              'rateUnit': rateUnit,
              'rentalRate': _decimal('rentalRate'),
              'depositAmount': _decimal('depositAmount'),
              'isActive': active,
            },
          );
          break;
        case 'create' when widget.menuCode == '60004':
          final response = _map(
            await widget.api.post(
              '$base/bookings',
              body: {
                'branchId': branchId,
                'customerId': customerId,
                'startAt': _offsetDate(
                  text['startDate']!.text,
                  text['startTime']!.text,
                ),
                'endAt': _offsetDate(
                  text['endDate']!.text,
                  text['endTime']!.text,
                ),
                'idempotencyKey': _requestKey(),
                'lines': bookingLines.entries
                    .map((e) => {'rentalItemId': e.key, 'quantity': e.value})
                    .toList(),
              },
            ),
          );
          _setReceiptMessage(response);
          break;
        case 'payment':
          await widget.api.post(
            '$base/bookings/$bookingId/payments',
            body: {
              'kind': paymentKind,
              'amount': _decimal('amount'),
              'method': paymentMethod,
              'referenceNo': _text('referenceNo'),
              'idempotencyKey': _requestKey(),
            },
          );
          break;
        case 'handover':
          final staff = await _uploadSignature(
            staffSignKey,
            'HANDOVER_STAFF_SIGN',
          );
          final customer = await _uploadSignature(
            customerSignKey,
            'HANDOVER_CUSTOMER_SIGN',
          );
          final serialSelection = <_Row>[];
          for (final line in detailLines) {
            final lineId = _lineId(line);
            final ids = serialIds[lineId] ?? [];
            serialSelection.add({'bookingLineId': lineId, 'instanceIds': ids});
          }
          await widget.api.post(
            '$base/bookings/$bookingId/handover',
            body: {
              'staffSignAttachmentId': staff,
              'customerSignAttachmentId': customer,
              'serials': serialSelection,
            },
          );
          break;
        case 'return':
          final staff = await _uploadSignature(
            staffSignKey,
            'RETURN_STAFF_SIGN',
          );
          final customer = await _uploadSignature(
            customerSignKey,
            'RETURN_CUSTOMER_SIGN',
          );
          final returnLines = <_Row>[];
          for (final line in detailLines) {
            final lineId = _lineId(line);
            final fields = returnFields[lineId]!;
            final qty = int.tryParse(fields['quantity']!.text) ?? 0;
            if (qty <= 0) continue;
            returnLines.add({
              'bookingLineId': lineId,
              'quantity': qty,
              'condition': returnConditions[lineId] ?? 'OK',
              'damageAmount': double.tryParse(fields['damage']!.text) ?? 0,
              'remark': fields['remark']!.text.trim(),
              'instanceIds': serialIds[lineId] ?? <int>[],
            });
          }
          if (returnLines.isEmpty) {
            throw StateError('ระบุจำนวนของที่รับคืนอย่างน้อย 1 รายการ');
          }
          await widget.api.post(
            '$base/bookings/$bookingId/returns',
            body: {
              'staffSignAttachmentId': staff,
              'customerSignAttachmentId': customer,
              'lines': returnLines,
            },
          );
          break;
        case 'approve-settlement':
          await widget.api.post(
            '$base/bookings/$bookingId/settlement/approve',
            body: {
              'approvedDeduction': _decimal('approvedDeduction'),
              'reason': _text('reason'),
            },
          );
          break;
        case 'refund':
          await widget.api.post(
            '$base/bookings/$bookingId/settlement/refund',
            body: {
              'method': refundMethod,
              'referenceNo': _text('referenceNo'),
              'idempotencyKey': _requestKey(),
            },
          );
          break;
        case 'cancel':
          await widget.api.post(
            '$base/bookings/$bookingId/cancel',
            body: {
              'reason': _text('reason'),
              'refundMethod': refundMethod,
              'referenceNo': _text('referenceNo'),
            },
          );
          break;
        case 'transfer':
          final quantity = int.tryParse(_text('transferQuantity')) ?? 0;
          final serials = _text('serialNo')
              .split(RegExp(r'[\s,;]+'))
              .where((value) => value.isNotEmpty)
              .toList();
          final instanceIds = <int>[];
          for (final serial in serials) {
            final result = _map(
              await widget.api.get(
                '$base/items/${widget.row?['id']}/serial-lookup',
                query: {
                  'otherWarehouseId': '$warehouseId',
                  'direction': transferDirection,
                  'serialNo': serial,
                },
              ),
            );
            instanceIds.add((result['id'] as num).toInt());
          }
          if (widget.row?['requireSerial'] == true &&
              instanceIds.length != quantity) {
            throw StateError(
              'ของเช่าชนิดนี้ต้องระบุ Serial Number ให้ครบตามจำนวน',
            );
          }
          await widget.api.post(
            '$base/stock-transfers',
            body: {
              'rentalItemId': widget.row?['id'],
              'otherWarehouseId': warehouseId,
              'direction': transferDirection,
              'quantity': quantity,
              'instanceIds': instanceIds,
              'idempotencyKey': _requestKey(),
            },
          );
          break;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = rentalErrorText(e, _formTitle));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  double _decimal(String name) =>
      double.tryParse(_text(name).replaceAll(',', '')) ?? 0;
  String _text(String name) => text[name]?.text.trim() ?? '';
  void _setReceiptMessage(_Row result) {
    error = null;
  }

  Future<int> _uploadSignature(
    GlobalKey<RentalSignaturePadState> key,
    String kind,
  ) async {
    final bytes = await key.currentState?.capture();
    if (bytes == null) throw StateError('กรุณาลงลายเซ็นให้ครบทั้งสองฝ่าย');
    final result = _map(
      await rentalUpload(
        '$base/bookings/$bookingId/attachments',
        fileName: '$kind.png',
        bytes: bytes,
        fields: {'kind': kind},
      ),
    );
    return (result['id'] as num).toInt();
  }

  Future<void> _uploadPhoto(int lineId, String kind) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = picked?.files.firstOrNull;
      if (file?.bytes == null || file!.bytes!.isEmpty) return;
      final result = _map(
        await rentalUpload(
          '$base/bookings/$bookingId/attachments',
          fileName: file.name,
          bytes: file.bytes!,
          fields: {'kind': kind, 'bookingLineId': '$lineId'},
        ),
      );
      photoIds[lineId] = (result['id'] as num).toInt();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = rentalErrorText(e, 'แนบรูปหลักฐาน'));
    }
  }

  Future<void> _downloadAttachment(_Row attachment) async {
    try {
      await rentalDownload(
        '$base/attachments/${attachment['AttachmentID']}',
        fileName: '${attachment['OriginalName']}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = rentalErrorText(e, 'ดาวน์โหลดเอกสาร'));
      }
    }
  }

  Future<void> _lookupSerial(int lineId, String stage) async {
    final input = serialFields[lineId]?.text.trim() ?? '';
    if (input.isEmpty) return;
    try {
      final response = _map(
        await widget.api.get(
          '$base/bookings/$bookingId/serial-lookup',
          query: {'serialNo': input, 'stage': stage},
        ),
      );
      final id = (response['id'] as num).toInt();
      if (!(serialIds[lineId] ??= []).contains(id)) serialIds[lineId]!.add(id);
      serialFields[lineId]!.clear();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) {
        setState(() => error = rentalErrorText(e, 'ตรวจสอบ Serial Number'));
      }
    }
  }

  Widget _field(
    String key,
    String label, {
    bool number = false,
    bool required = false,
    int maxLines = 1,
  }) => TextFormField(
    controller: text[key],
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    maxLines: maxLines,
    decoration: rentalField(widget.tokens, '$label${required ? ' *' : ''}'),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'กรุณากรอก$label' : null
        : null,
  );

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> changed,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: rentalField(widget.tokens, label),
    items: items,
    onChanged: changed,
  );

  List<Widget> _fields() {
    final branches = _rows(widget.options['branches']);
    final warehouses = _rows(widget.options['warehouses']);
    final rentalWarehouses = warehouses
        .where((w) => w['isRental'] == true)
        .toList();
    switch (action) {
      case 'create' when widget.menuCode == '60002':
        return [
          _dropdown<int>(
            label: 'สาขา *',
            value: branchId,
            items: branches
                .map(
                  (b) => DropdownMenuItem(
                    value: (b['id'] as num).toInt(),
                    child: Text(
                      '${b['code']} ${b['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            changed: (v) => setState(() {
              branchId = v;
              if (!rentalWarehouses.any(
                (warehouse) =>
                    warehouse['id'] == warehouseId &&
                    warehouse['branchId'] == v,
              )) {
                warehouseId = null;
              }
            }),
          ),
          _dropdown<int>(
            label: 'สินค้า *',
            value: rentalItemId,
            items: _rows(widget.options['items'])
                .map(
                  (i) => DropdownMenuItem(
                    value: (i['id'] as num).toInt(),
                    child: Text(
                      '${i['code']} ${i['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            changed: (v) => setState(() => rentalItemId = v),
          ),
          _dropdown<int>(
            label: 'คลังเช่า *',
            value: warehouseId,
            items: rentalWarehouses
                .where((w) => branchId == null || w['branchId'] == branchId)
                .map(
                  (w) => DropdownMenuItem(
                    value: (w['id'] as num).toInt(),
                    child: Text(
                      '${w['code']} ${w['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            changed: (v) => setState(() => warehouseId = v),
          ),
          _dropdown<String>(
            label: 'คิดค่าเช่าต่อ',
            value: rateUnit,
            items: const [
              DropdownMenuItem(value: 'DAY', child: Text('วัน')),
              DropdownMenuItem(value: 'HOUR', child: Text('ชั่วโมง')),
            ],
            changed: (v) => setState(() => rateUnit = v ?? 'DAY'),
          ),
          _field('rentalRate', 'ค่าเช่า', number: true, required: true),
          _field('depositAmount', 'เงินมัดจำ', number: true, required: true),
          SwitchListTile(
            value: requireSerial,
            onChanged: (v) => setState(() => requireSerial = v),
            title: const Text('บังคับบันทึก Serial Number'),
          ),
        ];
      case 'edit':
        return [
          _field('rentalRate', 'ค่าเช่า', number: true, required: true),
          _field('depositAmount', 'เงินมัดจำ', number: true, required: true),
          _dropdown<String>(
            label: 'คิดค่าเช่าต่อ',
            value: rateUnit,
            items: const [
              DropdownMenuItem(value: 'DAY', child: Text('วัน')),
              DropdownMenuItem(value: 'HOUR', child: Text('ชั่วโมง')),
            ],
            changed: (v) => setState(() => rateUnit = v ?? 'DAY'),
          ),
          SwitchListTile(
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('เปิดใช้งาน'),
          ),
        ];
      case 'create' when widget.menuCode == '60004':
        return [
          _dropdown<int>(
            label: 'สาขา *',
            value: branchId,
            items: branches
                .map(
                  (b) => DropdownMenuItem(
                    value: (b['id'] as num).toInt(),
                    child: Text(
                      '${b['code']} ${b['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            changed: (v) {
              setState(() => branchId = v);
              _loadAvailability();
            },
          ),
          _dropdown<int>(
            label: 'ลูกค้า *',
            value: customerId,
            items: _rows(widget.options['customers'])
                .map(
                  (c) => DropdownMenuItem(
                    value: (c['id'] as num).toInt(),
                    child: Text(
                      '${c['code']} ${c['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            changed: (v) => setState(() => customerId = v),
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  'startDate',
                  'วันที่เริ่ม (YYYY-MM-DD)',
                  required: true,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: _field('startTime', 'เวลา')),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  'endDate',
                  'วันที่คืน (YYYY-MM-DD)',
                  required: true,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: _field('endTime', 'เวลา')),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _loadAvailability,
            icon: const Icon(Icons.search),
            label: const Text('ตรวจสอบของว่าง'),
          ),
          if (loading) const LinearProgressIndicator(),
          ...available.map((item) {
            final id = (item['id'] as num).toInt();
            return CheckboxListTile(
              value: bookingLines.containsKey(id),
              onChanged: (yes) => setState(
                () => yes == true
                    ? bookingLines[id] = 1
                    : bookingLines.remove(id),
              ),
              title: Text('${item['code']} ${item['name']}'),
              subtitle: Text(
                'ว่าง ${item['available']} · เช่า ${item['rate']} · มัดจำ ${item['deposit']}',
              ),
              secondary: bookingLines.containsKey(id)
                  ? SizedBox(
                      width: 64,
                      child: TextFormField(
                        initialValue: '${bookingLines[id]}',
                        keyboardType: TextInputType.number,
                        decoration: rentalField(widget.tokens, 'จำนวน'),
                        onChanged: (v) =>
                            bookingLines[id] = int.tryParse(v) ?? 1,
                      ),
                    )
                  : null,
            );
          }),
        ];
      case 'payment':
        return [
          _summaryHeader(),
          _dropdown<String>(
            label: 'รายการรับเงิน',
            value: paymentKind,
            items: const [
              DropdownMenuItem(value: 'RENT', child: Text('ค่าเช่า')),
              DropdownMenuItem(value: 'DEPOSIT', child: Text('มัดจำ')),
              DropdownMenuItem(
                value: 'ADDITIONAL',
                child: Text('ยอดค่าเสียหายเพิ่มเติม'),
              ),
            ],
            changed: (v) {
              setState(() => paymentKind = v ?? 'RENT');
              _refreshPaymentAmount();
            },
          ),
          _field('amount', 'จำนวนเงิน', number: true, required: true),
          _dropdown<String>(
            label: 'วิธีรับเงิน',
            value: paymentMethod,
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
              DropdownMenuItem(value: 'TRANSFER', child: Text('โอนเงิน')),
            ],
            changed: (v) => setState(() => paymentMethod = v ?? 'CASH'),
          ),
          if (paymentMethod == 'TRANSFER')
            _field('referenceNo', 'เลขอ้างอิง', required: true),
        ];
      case 'handover':
        return [
          _summaryHeader(),
          _signatureBlock('HANDOVER'),
          ...detailLines.map(
            (line) => _evidenceLine(line, 'HANDOVER_PHOTO', 'HANDOVER'),
          ),
          ...detailLines
              .where((line) => line['RequireSerialSnapshot'] == true)
              .map((line) => _serialInput(line, 'HANDOVER')),
        ];
      case 'return':
        return [
          _summaryHeader(),
          _signatureBlock('RETURN'),
          ...detailLines
              .where((line) => _outstanding(line) > 0)
              .map((line) => _returnLine(line)),
          ...detailLines
              .where((line) => line['RequireSerialSnapshot'] == true)
              .map((line) => _serialInput(line, 'RETURN')),
        ];
      case 'approve-settlement':
        return [
          _summaryHeader(),
          Text(
            'ค่าเสียหายเสนอ ${settlement['proposedDamage'] ?? 0} · ค่าคืนช้า ${settlement['proposedLate'] ?? 0}',
          ),
          _field(
            'approvedDeduction',
            'ยอดหักที่อนุมัติ',
            number: true,
            required: true,
          ),
          _field('reason', 'เหตุผล', required: true, maxLines: 3),
        ];
      case 'refund':
        return [
          _summaryHeader(),
          Text(
            'ยอดคืน ${settlement['RefundDue'] ?? settlement['refundDue'] ?? 0} · ยอดเพิ่ม ${settlement['AdditionalDue'] ?? settlement['additionalDue'] ?? 0}',
          ),
          _dropdown<String>(
            label: 'วิธีคืนเงิน',
            value: refundMethod,
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
              DropdownMenuItem(value: 'TRANSFER', child: Text('โอนเงิน')),
            ],
            changed: (v) => setState(() => refundMethod = v ?? 'CASH'),
          ),
          if (refundMethod == 'TRANSFER')
            _field('referenceNo', 'เลขอ้างอิง', required: true),
        ];
      case 'cancel':
        return [
          _summaryHeader(),
          _field('reason', 'เหตุผลการยกเลิก', required: true, maxLines: 3),
          _dropdown<String>(
            label: 'วิธีคืนเงิน',
            value: refundMethod,
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
              DropdownMenuItem(value: 'TRANSFER', child: Text('โอนเงิน')),
            ],
            changed: (v) => setState(() => refundMethod = v ?? 'CASH'),
          ),
          if (refundMethod == 'TRANSFER')
            _field('referenceNo', 'เลขอ้างอิง', required: true),
        ];
      case 'transfer':
        return [
          _summaryHeader(),
          _dropdown<String>(
            label: 'ทิศทาง',
            value: transferDirection,
            items: const [
              DropdownMenuItem(
                value: 'TO_RENTAL',
                child: Text('คลังอื่น → คลังเช่า'),
              ),
              DropdownMenuItem(
                value: 'FROM_RENTAL',
                child: Text('คลังเช่า → คลังอื่น'),
              ),
            ],
            changed: (v) =>
                setState(() => transferDirection = v ?? 'TO_RENTAL'),
          ),
          _dropdown<int>(
            label: 'คลังอื่น *',
            value: warehouseId,
            items: warehouses
                .where((w) => w['isRental'] != true)
                .map(
                  (w) => DropdownMenuItem(
                    value: (w['id'] as num).toInt(),
                    child: Text(
                      '${w['code']} ${w['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            changed: (v) => setState(() => warehouseId = v),
          ),
          _field('transferQuantity', 'จำนวน', number: true, required: true),
          TextField(
            controller: text['serialNo'],
            maxLines: 2,
            decoration: rentalField(
              widget.tokens,
              'Serial Number (สแกนแล้วกด Enter หรือคั่นด้วยบรรทัดใหม่)',
            ),
            onSubmitted: (_) => setState(() => {}),
          ),
        ];
      case 'detail':
        return [
          _summaryHeader(),
          ...detailLines.map(
            (line) => Text(
              '${line['ItemCodeSnapshot'] ?? ''} ${line['ItemNameSnapshot'] ?? ''} · ${line['Quantity'] ?? 0} ชิ้น',
            ),
          ),
          const SizedBox(height: 8),
          Text('ประวัติรับเงิน', style: widget.tokens.sectionStyle),
          ..._rows(details['payments']).map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p['Kind']} · ${p['Amount']} · ${p['Method']}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'พิมพ์ใบรับเงิน/คืนเงิน',
                    onPressed: () => _printReceipt(p),
                    icon: Icon(
                      Icons.print_outlined,
                      color: widget.tokens.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text('เอกสารแนบ', style: widget.tokens.sectionStyle),
          ...existingAttachments.map(
            (a) => Row(
              children: [
                Expanded(child: Text('${a['Kind']} · ${a['OriginalName']}')),
                IconButton(
                  tooltip: 'ดาวน์โหลด',
                  onPressed: () => _downloadAttachment(a),
                  icon: Icon(
                    Icons.download_outlined,
                    color: widget.tokens.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return const [Text('ไม่พบแบบฟอร์มของรายการนี้')];
    }
  }

  Future<void> _printReceipt(_Row payment) async {
    final value = payment['PaymentID'] ?? payment['paymentId'] ?? payment['id'];
    if (value is! num) {
      if (mounted) setState(() => error = 'ไม่พบเลขรายการรับเงินสำหรับพิมพ์');
      return;
    }
    try {
      final data = _map(
        await widget.api.get('$base/payments/${value.toInt()}/receipt-data'),
      );
      await RentalReceiptPdf.print(data);
    } catch (e) {
      if (mounted) setState(() => error = rentalErrorText(e, 'พิมพ์ใบรับเงิน'));
    }
  }

  Widget _summaryHeader() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: widget.tokens.primaryColor.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(widget.tokens.radius),
    ),
    child: Text(
      '${widget.row?['code'] ?? widget.row?['BookingCode'] ?? 'รายการเช่า'} · ${widget.row?['status'] ?? ''}',
      style: widget.tokens.sectionStyle,
    ),
  );

  Widget _signatureBlock(String stage) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('ลายเซ็นยืนยัน', style: widget.tokens.sectionStyle),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('พนักงาน'),
                RentalSignaturePad(key: staffSignKey, tokens: widget.tokens),
              ],
            ),
          ),
          SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ลูกค้า'),
                RentalSignaturePad(key: customerSignKey, tokens: widget.tokens),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _evidenceLine(_Row line, String kind, String stage) {
    final id = _lineId(line);
    final uploaded =
        photoIds.containsKey(id) ||
        existingAttachments.any(
          (a) =>
              (a['BookingLineID'] as num?)?.toInt() == id && a['Kind'] == kind,
        );
    return LaooSurfaceCard(
      tokens: widget.tokens,
      child: Row(
        children: [
          Expanded(
            child: Text(_lineName(line), style: widget.tokens.tableStyle),
          ),
          Icon(
            uploaded ? Icons.check_circle : Icons.image_outlined,
            color: uploaded
                ? widget.tokens.primaryColor
                : widget.tokens.borderColor,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _uploadPhoto(id, kind),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(uploaded ? 'เปลี่ยนรูป' : 'แนบรูปก่อนส่งมอบ'),
          ),
        ],
      ),
    );
  }

  Widget _serialInput(_Row line, String stage) {
    final id = _lineId(line);
    final controller = serialFields[id]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_lineName(line)} · Serial ที่อ่านได้ ${serialIds[id]?.length ?? 0}',
          style: widget.tokens.tableStyle,
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: rentalField(
                  widget.tokens,
                  'สแกน/กรอก SN แล้วกด Enter',
                ),
                onSubmitted: (_) => _lookupSerial(id, stage),
              ),
            ),
            IconButton(
              tooltip: 'ตรวจสอบ SN',
              onPressed: () => _lookupSerial(id, stage),
              icon: Icon(Icons.search, color: widget.tokens.primaryColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _returnLine(_Row line) {
    final id = _lineId(line), fields = returnFields[_lineId(line)]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_lineName(line)} · คงค้าง ${_outstanding(line)} ชิ้น',
          style: widget.tokens.sectionStyle,
        ),
        _dropdown<String>(
          label: 'สภาพของรายการ',
          value: returnConditions[id] ?? 'OK',
          items: const [
            DropdownMenuItem(value: 'OK', child: Text('ปกติ')),
            DropdownMenuItem(value: 'DAMAGED', child: Text('ชำรุด')),
            DropdownMenuItem(value: 'LOST', child: Text('สูญหาย')),
          ],
          changed: (value) =>
              setState(() => returnConditions[id] = value ?? 'OK'),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: fields['quantity'],
                keyboardType: TextInputType.number,
                decoration: rentalField(widget.tokens, 'จำนวนที่คืน'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: fields['damage'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: rentalField(widget.tokens, 'ค่าเสียหาย'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: fields['remark'],
          decoration: rentalField(widget.tokens, 'หมายเหตุสภาพของ'),
        ),
        const SizedBox(height: 8),
        _evidenceLine(line, 'RETURN_PHOTO', 'RETURN'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final title = '${widget.title} > $_formTitle';
    return LaooActionDialog(
      tokens: t,
      icon: rentalMenuIcon(widget.iconName),
      title: title,
      width: 480,
      content: loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._fields().map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: field,
                    ),
                  ),
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        if (action != 'detail')
          FilledButton.icon(
            onPressed: saving || loading ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ปิด'),
          ),
      ],
    );
  }
}

class RentalSignaturePad extends StatefulWidget {
  const RentalSignaturePad({super.key, required this.tokens});
  final LaooWorkspaceUiTokens tokens;
  @override
  State<RentalSignaturePad> createState() => RentalSignaturePadState();
}

class RentalSignaturePadState extends State<RentalSignaturePad> {
  final boundary = GlobalKey();
  final points = <Offset?>[];
  Future<Uint8List?> capture() async {
    if (points.whereType<Offset>().isEmpty) return null;
    final render =
        boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (render == null) return null;
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RepaintBoundary(
        key: boundary,
        child: GestureDetector(
          onPanUpdate: (e) {
            final box = context.findRenderObject() as RenderBox;
            setState(() => points.add(box.globalToLocal(e.globalPosition)));
          },
          onPanEnd: (_) => setState(() => points.add(null)),
          child: Container(
            height: 100,
            width: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: widget.tokens.borderColor),
              borderRadius: BorderRadius.circular(widget.tokens.radius),
            ),
            child: CustomPaint(
              painter: _SignaturePainter(points, widget.tokens.primaryColor),
              size: const Size(190, 100),
            ),
          ),
        ),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: IconButton(
          tooltip: 'ล้างลายเซ็น',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(points.clear),
          icon: const Icon(Icons.refresh, size: 18),
        ),
      ),
    ],
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points, this.color);
  final List<Offset?> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => old.points != points;
}
