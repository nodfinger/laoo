import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'shift_template_models.dart';
import 'shift_template_repository.dart';

class ShiftTemplatePage extends StatefulWidget {
  const ShiftTemplatePage({super.key});
  @override
  State<ShiftTemplatePage> createState() => _ShiftTemplatePageState();
}

class _ShiftTemplatePageState extends State<ShiftTemplatePage> {
  final search = TextEditingController();
  late final JsonApiClient api;
  late final ShiftTemplateRepository repo;
  ShiftActions? actions;
  ShiftPageResult data = const ShiftPageResult(
    total: 0,
    page: 1,
    pageSize: 30,
    items: [],
  );
  bool loading = true;
  bool? active = true;
  String? message;
  bool messageError = false;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = ShiftTemplateRepository(api);
    _init();
  }

  @override
  void dispose() {
    search.dispose();
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final a = await repo.actions();
      if (!a.canView) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      if (mounted) setState(() => actions = a);
      await load();
    } catch (e) {
      show(timeErrorText(e), true);
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> load({int page = 1}) async {
    setState(() => loading = true);
    try {
      final x = await repo.list(
        search: search.text,
        active: active,
        page: page,
        pageSize: timePageSize,
      );
      if (mounted) setState(() => data = x);
    } catch (e) {
      show(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void show(String text, bool error) {
    if (mounted) {
      setState(() {
        message = text;
        messageError = error;
      });
    }
  }

  Future<void> edit([ShiftSummary? row]) async {
    ShiftDetail value = ShiftDetail.empty();
    try {
      if (row != null) value = await repo.get(row.id);
    } catch (e) {
      show(timeErrorText(e), true);
      return;
    }
    if (!mounted) return;
    final saved = await showDialog<ShiftDetail>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShiftDialog(value: value),
    );
    if (saved == null) return;
    try {
      await repo.save(saved);
      await load(page: data.page);
      show('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      show(timeErrorText(e), true);
    }
  }

  Future<void> remove(ShiftSummary row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 42),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text('${row.code} — ${row.name}'),
            ),
            const SizedBox(height: 12),
            const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(row);
      await load(page: data.page);
      show('ลบข้อมูลสำเร็จ', false);
    } catch (e) {
      show(timeErrorText(e), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = actions?.caption ?? 'Master กะทำงาน';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.shiftTemplates,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          caption,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (actions?.canCreate == true)
                        FilledButton.icon(
                          onPressed: () => edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: 300,
                            child: TextField(
                              controller: search,
                              onSubmitted: (_) => load(),
                              decoration: const InputDecoration(
                                labelText: 'ค้นหา',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<bool?>(
                              initialValue: active,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'สถานะ',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('ใช้งาน'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('ไม่ใช้งาน'),
                                ),
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('ทั้งหมด'),
                                ),
                              ],
                              onChanged: (v) => setState(() => active = v),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: loading ? null : () => load(),
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : data.items.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : ListView.separated(
                              itemCount: data.items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (c, i) {
                                final r = data.items[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${(data.page - 1) * data.pageSize + i + 1}',
                                    ),
                                  ),
                                  title: Text('${r.code} — ${r.name}'),
                                  subtitle: Text(
                                    '${r.segmentCount} ช่วงเวลา · ${r.sessionCount} รอบลงเวลา · ${r.active ? 'ใช้งาน' : 'ไม่ใช้งาน'}',
                                  ),
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'แก้ไข',
                                        onPressed: actions?.canEdit == true
                                            ? () => edit(r)
                                            : null,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'ลบ',
                                        onPressed: actions?.canDelete == true
                                            ? () => remove(r)
                                            : null,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: data.page > 1
                            ? () => load(page: data.page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        'หน้า ${data.page} จาก ${data.total == 0 ? 1 : (data.total / data.pageSize).ceil()}',
                      ),
                      IconButton(
                        onPressed: data.page * data.pageSize < data.total
                            ? () => load(page: data.page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message != null)
            Positioned(
              top: 12,
              right: 12,
              child: buildTimeMessage(
                message: message!,
                error: messageError,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftDialog extends StatefulWidget {
  const _ShiftDialog({required this.value});
  final ShiftDetail value;
  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  late ShiftDetail v;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    v = widget.value;
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
      child: Form(
        key: form,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      v.id == null ? 'เพิ่มกะทำงาน' : 'แก้ไขกะทำงาน',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Text('สถานะ'),
                      const SizedBox(width: 8),
                      Switch(
                        value: v.active,
                        onChanged: (x) => setState(() => v.active = x),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      field('รหัสกะ *', v.code, (x) => v.code = x, width: 220),
                      field('ชื่อกะ *', v.name, (x) => v.name = x, width: 360),
                      number('สายได้ (นาที)', v.late, (x) => v.late = x),
                      number('ออกก่อนได้ (นาที)', v.early, (x) => v.early = x),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: v.effectiveFrom,
                        firstDate: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                      );
                      if (picked != null) {
                        setState(() => v.effectiveFrom = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันที่เริ่มใช้ *',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(
                        '${v.effectiveFrom.day.toString().padLeft(2, '0')}/'
                        '${v.effectiveFrom.month.toString().padLeft(2, '0')}/'
                        '${v.effectiveFrom.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  field(
                    'รายละเอียด',
                    v.description,
                    (x) => v.description = x,
                    width: double.infinity,
                    required: false,
                  ),
                  const SizedBox(height: 20),
                  header(
                    'ช่วงเวลาของกะ',
                    () => setState(
                      () => v.segments.add(
                        ShiftSegment(sequenceNo: v.segments.length + 1),
                      ),
                    ),
                  ),
                  ...v.segments.asMap().entries.map(
                    (e) => segment(e.key, e.value),
                  ),
                  const SizedBox(height: 20),
                  header(
                    'รอบลงเวลา',
                    () => setState(
                      () => v.rules.add(
                        ShiftSessionRule(sequenceNo: v.rules.length + 1),
                      ),
                    ),
                  ),
                  ...v.rules.asMap().entries.map((e) => rule(e.key, e.value)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget header(String text, VoidCallback add) => Row(
    children: [
      Expanded(
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      OutlinedButton.icon(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มรายการ'),
      ),
    ],
  );
  Widget segment(int index, ShiftSegment x) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: x.type,
              decoration: const InputDecoration(labelText: 'ประเภท'),
              items: const [
                DropdownMenuItem(value: 'WORK', child: Text('ทำงาน')),
                DropdownMenuItem(value: 'BREAK', child: Text('พัก')),
                DropdownMenuItem(value: 'OT', child: Text('OT')),
              ],
              onChanged: (z) => x.type = z!,
            ),
          ),
          day('วันเริ่ม', x.startDay, (z) => x.startDay = z),
          time('เวลาเริ่ม', x.startTime, (z) => x.startTime = z),
          day('วันสิ้นสุด', x.endDay, (z) => x.endDay = z),
          time('เวลาสิ้นสุด', x.endTime, (z) => x.endTime = z),
          IconButton(
            onPressed: v.segments.length > 1
                ? () => setState(() => v.segments.removeAt(index))
                : null,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    ),
  );
  Widget rule(int index, ShiftSessionRule x) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: field(
                  'ชื่อรอบ *',
                  x.name,
                  (z) => x.name = z,
                  width: double.infinity,
                ),
              ),
              IconButton(
                onPressed: v.rules.length > 1
                    ? () => setState(() => v.rules.removeAt(index))
                    : null,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              day('วันเข้างาน', x.inDay, (z) => x.inDay = z),
              time('เวลาเข้างาน', x.inTime, (z) => x.inTime = z),
              day('วันออกงาน', x.outDay, (z) => x.outDay = z),
              time('เวลาออกงาน', x.outTime, (z) => x.outTime = z),
              day('วันเริ่มรับเข้า', x.inStartDay, (z) => x.inStartDay = z),
              time('เริ่มรับเข้า', x.inStart, (z) => x.inStart = z),
              day('วันสิ้นสุดรับเข้า', x.inEndDay, (z) => x.inEndDay = z),
              time('สิ้นสุดรับเข้า', x.inEnd, (z) => x.inEnd = z),
              day('วันเริ่มรับออก', x.outStartDay, (z) => x.outStartDay = z),
              time('เริ่มรับออก', x.outStart, (z) => x.outStart = z),
              day('วันสิ้นสุดรับออก', x.outEndDay, (z) => x.outEndDay = z),
              time('สิ้นสุดรับออก', x.outEnd, (z) => x.outEnd = z),
            ],
          ),
        ],
      ),
    ),
  );
  Widget field(
    String label,
    String value,
    ValueChanged<String> change, {
    double width = 180,
    bool required = true,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      validator: (x) =>
          required && x!.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null,
      onChanged: change,
    ),
  );
  Widget number(String label, int value, ValueChanged<int> change) => SizedBox(
    width: 170,
    child: TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (x) =>
          int.tryParse(x ?? '') == null ? 'กรุณาระบุตัวเลข' : null,
      onChanged: (x) => change(int.tryParse(x) ?? 0),
    ),
  );
  Widget day(String label, int value, ValueChanged<int> change) => SizedBox(
    width: 145,
    child: DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: 0, child: Text('วันเริ่มกะ')),
        DropdownMenuItem(value: 1, child: Text('วันถัดไป')),
      ],
      onChanged: (x) => change(x!),
    ),
  );
  Widget time(String label, String value, ValueChanged<String> change) =>
      SizedBox(
        width: 125,
        child: TextFormField(
          initialValue: value,
          decoration: InputDecoration(labelText: label, hintText: 'HH:mm'),
          validator: (x) =>
              RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(x ?? '')
              ? null
              : 'HH:mm',
          onChanged: change,
        ),
      );
  void save() {
    for (var i = 0; i < v.segments.length; i++) {
      v.segments[i].sequenceNo = i + 1;
    }
    for (var i = 0; i < v.rules.length; i++) {
      v.rules[i].sequenceNo = i + 1;
    }
    if (form.currentState!.validate()) Navigator.pop(context, v);
  }
}
