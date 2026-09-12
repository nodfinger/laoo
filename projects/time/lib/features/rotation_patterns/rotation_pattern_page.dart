import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'rotation_pattern_models.dart';
import 'rotation_pattern_repository.dart';

class RotationPatternPage extends StatefulWidget {
  const RotationPatternPage({super.key});
  @override
  State<RotationPatternPage> createState() => _State();
}

class _State extends State<RotationPatternPage> {
  late final JsonApiClient api;
  late final RotationPatternRepository repo;
  RotationActions? actions;
  List<ShiftOption> shifts = [];
  RotationResult data = const RotationResult(
    total: 0,
    page: 1,
    pageSize: 30,
    items: [],
  );
  bool loading = true;
  bool cards = false;
  String? message;
  bool error = false;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = RotationPatternRepository(api);
    init();
  }

  @override
  void dispose() {
    disposeTimeApiClient(api);
    super.dispose();
  }

  void notice(String s, bool e) {
    if (mounted) {
      setState(() {
        message = s;
        error = e;
      });
    }
  }

  Future<void> init() async {
    try {
      final values = await Future.wait([repo.actions(), repo.shifts()]);
      final a = values[0] as RotationActions;
      if (!a.view) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      setState(() {
        actions = a;
        shifts = values[1] as List<ShiftOption>;
      });
      await load();
    } catch (e) {
      notice(timeErrorText(e), true);
      setState(() => loading = false);
    }
  }

  Future<void> load({int page = 1}) async {
    setState(() => loading = true);
    try {
      final x = await repo.list(page: page, pageSize: timePageSize);
      if (mounted) setState(() => data = x);
    } catch (e) {
      notice(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([RotationPattern? row]) async {
    var x = RotationPattern.empty();
    if (row != null) {
      try {
        x = await repo.get(row.id!);
      } catch (e) {
        notice(timeErrorText(e), true);
        return;
      }
    }
    if (!mounted) return;
    final saved = await showDialog<RotationPattern>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Dialog(value: x, shifts: shifts),
    );
    if (saved == null) return;
    try {
      await repo.save(saved);
      await load(page: data.page);
      notice('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Future<void> remove(RotationPattern x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 42),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text('${x.code} — ${x.name}'),
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
    if (ok == true) {
      try {
        await repo.delete(x);
        await load(page: data.page);
        notice('ลบข้อมูลสำเร็จ', false);
      } catch (e) {
        notice(timeErrorText(e), true);
      }
    }
  }

  Widget _table() => LaooWorkspaceDataTable(
    tokens: timeUiTokens.workspace,
    headingRowColor: WidgetStatePropertyAll(
      timeUiTokens.primaryColor.withValues(alpha: .10),
    ),
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ'), columnWidth: FixedColumnWidth(112)),
      DataColumn(label: Text('รหัส')),
      DataColumn(label: Text('ชื่อรูปแบบ'), columnWidth: FlexColumnWidth()),
      DataColumn(label: Text('รอบ (วัน)')),
      DataColumn(label: Text('สถานะ')),
    ],
    rows: [
      for (var index = 0; index < data.items.length; index++)
        DataRow(
          cells: [
            DataCell(Text('${(data.page - 1) * data.pageSize + index + 1}')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'แก้ไข',
                    onPressed: actions?.edit == true
                        ? () => edit(data.items[index])
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'ลบ',
                    onPressed: actions?.delete == true
                        ? () => remove(data.items[index])
                        : null,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
            DataCell(Text(data.items[index].code)),
            DataCell(Text(data.items[index].name)),
            DataCell(Text('${data.items[index].cycleDays}')),
            DataCell(Text(data.items[index].active ? 'ใช้งาน' : 'ไม่ใช้งาน')),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final caption = actions?.caption ?? 'รูปแบบหมุนกะ';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.rotationPatterns,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: timeUiTokens.contentMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TimeCaptionCard(
                    api: api,
                    menuCode: TimeMenuCodes.rotationPatterns,
                    caption: caption,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LaooListCardToggle(
                          tokens: timeUiTokens.workspace,
                          cards: cards,
                          onChanged: (value) => setState(() => cards = value),
                        ),
                        if (actions?.create == true)
                          FilledButton.icon(
                            onPressed: () => edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่ม'),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: timeUiTokens.cardSpacing),
                  Expanded(
                    child: Card(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : data.items.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : cards
                          ? ListView.separated(
                              itemCount: data.items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (c, i) {
                                final x = data.items[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${(data.page - 1) * data.pageSize + i + 1}',
                                    ),
                                  ),
                                  title: Text('${x.code} — ${x.name}'),
                                  subtitle: Text('วงรอบ ${x.cycleDays} วัน'),
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'แก้ไข',
                                        onPressed: actions?.edit == true
                                            ? () => edit(x)
                                            : null,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'ลบ',
                                        onPressed: actions?.delete == true
                                            ? () => remove(x)
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
                            )
                          : _table(),
                    ),
                  ),
                  SizedBox(height: timeUiTokens.cardSpacing),
                  LaooPaginationCard(
                    tokens: timeUiTokens.workspace,
                    page: data.page,
                    pageCount: data.total == 0
                        ? 1
                        : (data.total / data.pageSize).ceil(),
                    pageSize: data.pageSize,
                    total: data.total,
                    onPrevious: data.page > 1
                        ? () => load(page: data.page - 1)
                        : null,
                    onNext: data.page * data.pageSize < data.total
                        ? () => load(page: data.page + 1)
                        : null,
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
                error: error,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dialog extends StatefulWidget {
  const _Dialog({required this.value, required this.shifts});
  final RotationPattern value;
  final List<ShiftOption> shifts;
  @override
  State<_Dialog> createState() => _DialogState();
}

class _DialogState extends State<_Dialog> {
  late final RotationPattern x;
  final key = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    x = widget.value;
  }

  void cycle(int n) {
    setState(() {
      x.cycleDays = n;
      x.days = List.generate(
        n,
        (i) => i < x.days.length
            ? (x.days[i]..dayNo = i + 1)
            : RotationDay(dayNo: i + 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Form(
        key: key,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      x.id == null ? 'เพิ่มรูปแบบหมุนกะ' : 'แก้ไขรูปแบบหมุนกะ',
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
                      Switch(
                        value: x.active,
                        onChanged: (v) => setState(() => x.active = v),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: x.code,
                    decoration: const InputDecoration(
                      labelText: 'รหัสรูปแบบ *',
                    ),
                    validator: req,
                    onChanged: (v) => x.code = v,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: x.effectiveFrom,
                        firstDate: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                      );
                      if (picked != null) {
                        setState(() => x.effectiveFrom = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันที่เริ่มใช้ *',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(
                        '${x.effectiveFrom.day.toString().padLeft(2, '0')}/'
                        '${x.effectiveFrom.month.toString().padLeft(2, '0')}/'
                        '${x.effectiveFrom.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: x.name,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อรูปแบบ *',
                    ),
                    validator: req,
                    onChanged: (v) => x.name = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: '${x.cycleDays}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนวันในวงรอบ *',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 366
                          ? 'ระบุ 1–366 วัน'
                          : null;
                    },
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 1 && n <= 366) cycle(n);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ตารางวงรอบ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ...x.days.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(width: 70, child: Text('วันที่ ${d.dayNo}')),
                          SizedBox(
                            width: 120,
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('วันหยุด'),
                              value: d.dayOff,
                              onChanged: (v) => setState(() => d.dayOff = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: d.dayOff ? null : d.shiftId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'กะทำงาน',
                              ),
                              items: widget.shifts
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        '${s.code} — ${s.name}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: d.dayOff
                                  ? null
                                  : (v) => setState(() => d.shiftId = v),
                              validator: (v) => !d.dayOff && v == null
                                  ? 'กรุณาเลือกกะ'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  FilledButton.icon(
                    onPressed: () {
                      if (key.currentState!.validate()) {
                        Navigator.pop(context, x);
                      }
                    },
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
  String? req(String? v) =>
      v == null || v.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;
}
