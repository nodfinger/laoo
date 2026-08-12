import 'package:flutter/material.dart';
import '../../presentation/widgets/support_workspace_shell.dart';

class EmployeeUxPage extends StatefulWidget {
  const EmployeeUxPage({super.key});
  @override
  State<EmployeeUxPage> createState() => _EmployeeUxPageState();
}

class _EmployeeUxPageState extends State<EmployeeUxPage> {
  bool card = false;
  bool form = false;
  final rows = const [
    ('EMP0001', 'สมชาย ใจดี', 'บริหาร', 'บุคคล'),
    ('EMP0002', 'สุดา รักงาน', 'ปฏิบัติการ', 'บริการ'),
  ];

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
        pageTitle: 'พนักงาน',
        activeMenu: 'laooEmployees',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: form ? _form() : _list(),
        ),
      );

  Widget _list() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: WorkspacePageTitle(title: 'พนักงาน', favoriteKey: 'laooEmployees')),
          FilledButton.icon(onPressed: () => setState(() => form = true), icon: const Icon(Icons.add), label: const Text('เพิ่ม')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          const SizedBox(width: 300, child: TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'ค้นหารหัส/ชื่อ/อีเมล', suffixIcon: Icon(Icons.arrow_forward)))),
          SizedBox(width: 150, child: DropdownButtonFormField<String>(initialValue: 'ทั้งหมด', decoration: const InputDecoration(labelText: 'สถานะ'), items: const [DropdownMenuItem(value: 'ทั้งหมด', child: Text('ทั้งหมด'))], onChanged: (_) {})),
          SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: 'ทุกฝ่าย/แผนก', decoration: const InputDecoration(labelText: 'ฝ่าย/แผนก'), items: const [DropdownMenuItem(value: 'ทุกฝ่าย/แผนก', child: Text('ทุกฝ่าย/แผนก'))], onChanged: (_) {})),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('ล้าง Filter')),
        ]),
        const SizedBox(height: 12),
        Row(children: [const Text('มุมมอง'), const SizedBox(width: 8), SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('List')), ButtonSegment(value: true, label: Text('Card'))], selected: {card}, onSelectionChanged: (v) => setState(() => card = v.first))]),
        const SizedBox(height: 12),
        Expanded(child: card ? _cards() : _table()),
        const SizedBox(height: 12),
        const Row(children: [OutlinedButton(onPressed: null, child: Text('ก่อนหน้า')), SizedBox(width: 8), FilledButton(onPressed: null, child: Text('1')), SizedBox(width: 8), OutlinedButton(onPressed: null, child: Text('ถัดไป')), SizedBox(width: 8), Text('แสดง 1-2 จาก 2 รายการ')]),
      ]);

  Widget _table() => Card(child: ListView.separated(itemCount: rows.length, separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade300), itemBuilder: (_, i) => ListTile(leading: Text('${i + 1}'), title: Text('${rows[i].$1} - ${rows[i].$2}'), subtitle: Text('ฝ่าย ${rows[i].$3} / แผนก ${rows[i].$4}'), trailing: Wrap(children: [IconButton(onPressed: () => setState(() => form = true), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: Colors.red))]))));

  Widget _cards() => ListView.separated(itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (_, i) => Card(child: ListTile(title: Text('${rows[i].$1} - ${rows[i].$2}'), subtitle: Text('ฝ่าย ${rows[i].$3}  แผนก ${rows[i].$4}\nสถานะ ใช้งาน'), isThreeLine: true, trailing: IconButton(onPressed: () => setState(() => form = true), icon: const Icon(Icons.edit_outlined)))));

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const Expanded(child: WorkspacePageTitle(title: 'พนักงาน > เพิ่ม', favoriteKey: 'laooEmployees')), OutlinedButton(onPressed: () => setState(() => form = false), child: const Text('ยกเลิก')), const SizedBox(width: 8), FilledButton(onPressed: () {}, child: const Text('บันทึก'))]),
        const SizedBox(height: 8),
        Expanded(child: SingleChildScrollView(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ข้อมูลส่วนตัว', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('สถานะ'), value: true, onChanged: (_) {}),
          Wrap(spacing: 12, runSpacing: 12, children: [for (final label in const ['รหัสพนักงาน *', 'ชื่อ-นามสกุล *', 'ชื่อเล่น', 'ฝ่าย', 'แผนก', 'ตำแหน่ง (MsPosition 007)', 'Email', 'โทรศัพท์', 'โทรศัพท์ส่วนตัว', 'วันที่เริ่มงาน']) SizedBox(width: 320, child: TextField(decoration: InputDecoration(labelText: label)))]),
          const SizedBox(height: 24),
          const Text('รูปภาพพนักงานเป็นทางการ (ไม่เกิน 100 KB)'), const SizedBox(height: 80),
          const Text('กรณีฉุกเฉินติดต่อ (สูงสุด 2 คน)'), const SizedBox(height: 70),
          const Text('ยานพาหนะส่วนตัว (สูงสุด 2 คัน)'), const SizedBox(height: 90),
        ]))))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [OutlinedButton(onPressed: () => setState(() => form = false), child: const Text('ยกเลิก')), const SizedBox(width: 8), FilledButton(onPressed: () {}, child: const Text('บันทึก'))])),
      ]);
}
