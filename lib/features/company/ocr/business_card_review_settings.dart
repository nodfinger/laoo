import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'business_card_ocr_api.dart';
import 'business_card_ocr_ui.dart';

class BusinessCardReviewSettings extends StatefulWidget {
  const BusinessCardReviewSettings({
    super.key,
    required this.canEdit,
    required this.saving,
  });
  final bool canEdit;
  final bool saving;
  @override
  BusinessCardReviewSettingsState createState() =>
      BusinessCardReviewSettingsState();
}

class _Review {
  String mode = 'ORG', level = 'DEP';
  Set<int> employees = {};
  void read(dynamic data) {
    if (data is! Map) return;
    mode = '${data['mode'] ?? 'ORG'}';
    level = '${data['level'] ?? 'DEP'}';
    employees = ((data['employeeIds'] as List?) ?? [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toSet();
  }

  Map<String, dynamic> json() => {
    'mode': mode,
    'level': level,
    'employeeIds': employees.toList(),
  };
}

class BusinessCardReviewSettingsState
    extends State<BusinessCardReviewSettings> {
  final api = BusinessCardOcrApi();
  final customer = _Review(), supplier = _Review();
  List<Map<String, dynamic>> employees = [], departments = [];
  bool loading = true, hasDivision = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await api.reviewSettings();
      if (!mounted) return;
      setState(() {
        hasDivision = data['hasDivision'] == true;
        customer.read(data['customer']);
        supplier.read(data['supplier']);
        if (!hasDivision) {
          customer.level = 'DEP';
          supplier.level = 'DEP';
        }
        employees = (data['employees'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        departments = (data['departments'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'โหลดการตั้งค่าผู้ตรวจสอบไม่สำเร็จ';
        });
    }
  }

  String? validationError() {
    if (loading || error != null)
      return 'กรุณารอให้โหลดการตั้งค่าผู้ตรวจสอบสำเร็จ';
    final missing = <String>[
      if (customer.mode == 'EMPLOYEE' && customer.employees.isEmpty)
        'ลูกค้า/ผู้ติดต่อ',
      if (supplier.mode == 'EMPLOYEE' && supplier.employees.isEmpty)
        'ผู้ขาย/ผู้ติดต่อ',
    ];
    return missing.isEmpty
        ? null
        : 'กรุณาเลือกพนักงานผู้ตรวจสอบสำหรับ ${missing.join(' และ ')}';
  }

  Map<String, dynamic> settings() => {
    'customer': customer.json(),
    'supplier': supplier.json(),
  };

  Future<void> _choose(_Review review) async {
    final chosen = {...review.employees};
    String search = '';
    int? department;
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) {
          final filtered = employees
              .where(
                (e) =>
                    (department == null || e['departmentId'] == department) &&
                    '${e['name']} ${e['department']}'.toLowerCase().contains(
                      search.toLowerCase(),
                    ),
              )
              .toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text(
              'เลือกพนักงานผู้ตรวจสอบ',
              style: businessCardOcrUi(context).captionStyle,
            ),
            content: SizedBox(
              width: 480,
              height: MediaQuery.sizeOf(context).height * .55,
              child: Column(
                children: [
                  TextField(
                    style: businessCardOcrUi(context).inputStyle,
                    decoration: ocrInput(
                      context,
                      'ค้นหาพนักงาน',
                      icon: Icons.search,
                    ),
                    onChanged: (v) => update(() => search = v.trim()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: department,
                    style: businessCardOcrUi(context).tableStyle,
                    decoration: ocrInput(context, 'แผนก'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทุกแผนก'),
                      ),
                      ...departments.map(
                        (d) => DropdownMenuItem<int?>(
                          value: (d['id'] as num).toInt(),
                          child: Text('${d['name']}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => update(() => department = v),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'เลือกแล้ว ${chosen.length} คน',
                      style: businessCardOcrUi(context).tableStyle,
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('ไม่พบพนักงาน'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, thickness: .6),
                            itemBuilder: (context, i) {
                              final e = filtered[i];
                              final id = (e['id'] as num).toInt();
                              return CheckboxListTile(
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                value: chosen.contains(id),
                                title: Text(
                                  '${e['name']}',
                                  style: businessCardOcrUi(context).tableStyle,
                                ),
                                subtitle: Text(
                                  '${e['department']}',
                                  style: businessCardOcrUi(context).tableStyle,
                                ),
                                onChanged: (v) => update(() {
                                  if (v == true) {
                                    chosen.add(id);
                                  } else {
                                    chosen.remove(id);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, chosen),
                child: const Text('ตกลง'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) setState(() => review.employees = result);
  }

  Widget _section(String title, _Review value) {
    final canChange = widget.canEdit && !widget.saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: businessCardOcrUi(context).sectionStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  businessCardOcrUi(context).radius,
                ),
              ),
              label: const Text('ตามสายงาน'),
              selected: value.mode == 'ORG',
              onSelected: canChange
                  ? (_) => setState(() => value.mode = 'ORG')
                  : null,
            ),
            ChoiceChip(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  businessCardOcrUi(context).radius,
                ),
              ),
              label: const Text('กำหนดชื่อผู้มีสิทธิตรวจสอบ'),
              selected: value.mode == 'EMPLOYEE',
              onSelected: canChange
                  ? (_) => setState(() => value.mode = 'EMPLOYEE')
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (value.mode == 'ORG') ...[
          if (hasDivision)
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      businessCardOcrUi(context).radius,
                    ),
                  ),
                  label: const Text('ตรวจจากระดับฝ่าย'),
                  selected: value.level == 'DIV',
                  onSelected: canChange
                      ? (_) => setState(() => value.level = 'DIV')
                      : null,
                ),
                ChoiceChip(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      businessCardOcrUi(context).radius,
                    ),
                  ),
                  label: const Text('ตรวจจากระดับแผนก'),
                  selected: value.level == 'DEP',
                  onSelected: canChange
                      ? (_) => setState(() => value.level = 'DEP')
                      : null,
                ),
              ],
            )
          else
            const Text('ตรวจจากระดับแผนก'),
        ] else ...[
          OutlinedButton.icon(
            onPressed: canChange ? () => _choose(value) : null,
            icon: const Icon(Icons.person_search),
            label: Text('เลือกพนักงาน (${value.employees.length} คน)'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: value.employees.map((id) {
              final matches = employees.where((e) => e['id'] == id);
              final name = matches.isEmpty
                  ? 'พนักงานไม่พร้อมใช้งาน ($id)'
                  : '${matches.first['name']}';
              return InputChip(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    businessCardOcrUi(context).radius,
                  ),
                ),
                label: Text(name),
                onDeleted: canChange
                    ? () => setState(() => value.employees.remove(id))
                    : null,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LaooSurfaceCard(
    tokens: businessCardOcrUi(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'การส่งตรวจสอบนามบัตร',
          style: businessCardOcrUi(context).sectionStyle,
        ),
        const SizedBox(height: 8),
        const Text('กำหนดผู้ตรวจสอบสำหรับการใช้งานในขั้นตอนถัดไป'),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Text(error!)
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _section('ลูกค้า/ผู้ติดต่อ', customer)),
                    const SizedBox(width: 24),
                    Expanded(child: _section('ผู้ขาย/ผู้ติดต่อ', supplier)),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('ลูกค้า/ผู้ติดต่อ', customer),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, thickness: .6),
                  ),
                  _section('ผู้ขาย/ผู้ติดต่อ', supplier),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}
