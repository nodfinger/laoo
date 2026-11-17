import 'dart:async';
import 'package:flutter/material.dart';
import '../ocr/business_card_ocr_ui.dart';
import 'contact_api.dart';

class ContactOcrCustomerSelection extends StatefulWidget {
  const ContactOcrCustomerSelection({
    super.key,
    required this.api,
    this.supplier = false,
  });
  final ContactApi api;
  final bool supplier;
  @override
  ContactOcrCustomerSelectionState createState() =>
      ContactOcrCustomerSelectionState();
}

class ContactOcrCustomerSelectionState
    extends State<ContactOcrCustomerSelection> {
  List<Map<String, dynamic>> customers = [];
  bool loading = true, canCreate = false;
  String? error, mode;
  int? customerId;
  String get _party => widget.supplier ? 'ผู้ขาย' : 'ลูกค้า';
  Timer? debounce;
  int requestId = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> _load([String search = '']) async {
    final request = ++requestId;
    try {
      final data = await widget.api.lookups(
        search: search,
        customerId: customerId,
      );
      if (!mounted || request != requestId) return;
      setState(() {
        final incoming = (data['customers'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (customerId != null && !incoming.any((e) => e['id'] == customerId)) {
          final previous = customers.where((e) => e['id'] == customerId);
          if (previous.isNotEmpty) incoming.insert(0, previous.first);
        }
        customers = incoming;
        canCreate = data['canCreateCustomer'] == true;
        error = null;
        loading = false;
      });
    } catch (_) {
      if (mounted && request == requestId)
        setState(() {
          loading = false;
          error = 'โหลดข้อมูล${_party}ไม่สำเร็จ กรุณาตรวจสิทธิ์และลองใหม่';
        });
    }
  }

  String? validate(Map<String, String> values) {
    if (loading || error != null) return 'กรุณารอให้โหลดข้อมูล${_party}สำเร็จ';
    if ((values['name'] ?? '').trim().isEmpty)
      return 'กรุณาเลือกและระบุชื่อผู้ติดต่อ';
    if (mode == null)
      return 'กรุณาเลือกเชื่อม${_party}เดิมหรือสร้าง${_party}ใหม่';
    if (mode == 'existing' && customerId == null)
      return 'กรุณาเลือก${_party}ที่ต้องการเชื่อม';
    if (mode == 'new' && (values['company'] ?? '').trim().isEmpty)
      return 'กรุณาเลือกและระบุชื่อบริษัทสำหรับสร้าง${_party}';
    if (mode == 'new' && (values['company'] ?? '').trim().length > 200)
      return 'ชื่อ${_party}ต้องไม่เกิน 200 ตัวอักษร';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = businessCardOcrUi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const LinearProgressIndicator()
        else if (error != null) ...[
          Text(error!),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _load,
              child: const Text('ลองใหม่'),
            ),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('เชื่อม${_party}เดิม'),
                selected: mode == 'existing',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radius),
                ),
                onSelected: (_) => setState(() {
                  mode = 'existing';
                  customerId = null;
                }),
              ),
              ChoiceChip(
                label: Text('สร้าง${_party}ใหม่'),
                selected: mode == 'new',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radius),
                ),
                onSelected: canCreate
                    ? (_) => setState(() {
                        mode = 'new';
                        customerId = null;
                      })
                    : null,
              ),
            ],
          ),
          if (!canCreate)
            Text(
              widget.supplier
                  ? 'การสร้างผู้ขายใหม่ต้องมีสิทธิ์เพิ่มข้อมูลผู้ขาย'
                  : 'การสร้างลูกค้าใหม่ต้องมีสิทธิ์เพิ่มข้อมูลลูกค้าและเปิดระบบขาย',
            ),
          if (mode == 'existing') ...[
            const SizedBox(height: 12),
            TextField(
              style: t.inputStyle,
              decoration: ocrInput(
                context,
                'ค้นหา${_party}',
                icon: Icons.search,
              ),
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _load(v.trim()),
                );
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: customerId,
              isExpanded: true,
              style: t.tableStyle,
              decoration: ocrInput(context, 'เลือก${_party}'),
              items: customers
                  .map(
                    (e) => DropdownMenuItem<int>(
                      value: (e['id'] as num).toInt(),
                      child: Text(
                        '${e['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => customerId = v),
            ),
            if (customers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'ไม่พบ${_party}ที่เลือกได้ หรือไม่มีสิทธิ์ดูข้อมูล${_party}',
                ),
              ),
          ],
          if (mode == 'new')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'ระบบใช้ชื่อบริษัทที่เลือกด้านบน และสร้างรหัส${_party}ให้อัตโนมัติ',
              ),
            ),
        ],
      ],
    );
  }
}
