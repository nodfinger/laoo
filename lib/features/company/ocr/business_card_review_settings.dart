import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import 'business_card_ocr_api.dart';
import 'business_card_ocr_ui.dart';

class BusinessCardReviewSettings extends StatefulWidget {
  const BusinessCardReviewSettings({super.key, required this.canEdit});
  final bool canEdit;
  @override
  State<BusinessCardReviewSettings> createState() =>
      _BusinessCardReviewSettingsState();
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

class _BusinessCardReviewSettingsState
    extends State<BusinessCardReviewSettings> {
  final api = BusinessCardOcrApi();
  final customer = _Review(), supplier = _Review();
  List<Map<String, dynamic>> employees = [], departments = [];
  bool loading = true, saving = false, hasDivision = false;
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

  Future<void> save() async {
    if ([
      customer,
      supplier,
    ].any((r) => r.mode == 'EMPLOYEE' && r.employees.isEmpty)) {
      showTimedSnackBar(
        context,
        message: 'กรุณาเลือกพนักงานผู้ตรวจสอบ',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await api.saveReviewSettings({
        'customer': customer.json(),
        'supplier': supplier.json(),
      });
      if (mounted)
        showTimedSnackBar(context, message: 'บันทึกการตั้งค่าผู้ตรวจสอบแล้ว');
    } catch (e) {
      if (mounted)
        showTimedSnackBar(
          context,
          message:
              'บันทึกการตั้งค่าผู้ตรวจสอบไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $e',
          error: true,
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> choose(_Review review) async {
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
            title: const Text('เลือกพนักงานผู้ตรวจสอบ'),
            content: SizedBox(
              width: 600,
              height: MediaQuery.sizeOf(context).height * .55,
              child: Column(
                children: [
                  TextField(
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
                    child: Text('เลือกแล้ว ${chosen.length} คน'),
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
                                value: chosen.contains(id),
                                title: Text('${e['name']}'),
                                subtitle: Text('${e['department']}'),
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

  Widget section(String title, _Review value) {
    final canChange = widget.canEdit && !saving;
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
              label: const Text('ตามสายงาน'),
              selected: value.mode == 'ORG',
              onSelected: canChange
                  ? (_) => setState(() => value.mode = 'ORG')
                  : null,
            ),
            ChoiceChip(
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
                  label: const Text('ตรวจจากระดับฝ่าย'),
                  selected: value.level == 'DIV',
                  onSelected: canChange
                      ? (_) => setState(() => value.level = 'DIV')
                      : null,
                ),
                ChoiceChip(
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
            onPressed: canChange ? () => choose(value) : null,
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
          section('ลูกค้า/ผู้ติดต่อ', customer),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: .6),
          ),
          section('ผู้ขาย/ผู้ติดต่อ', supplier),
          if (widget.canEdit) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  saving ? 'กำลังบันทึก…' : 'บันทึกการตั้งค่าผู้ตรวจสอบ',
                ),
              ),
            ),
          ],
        ],
      ],
    ),
  );
}
