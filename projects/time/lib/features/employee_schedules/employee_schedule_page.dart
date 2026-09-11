import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'employee_schedule_models.dart';
import 'employee_schedule_repository.dart';

class EmployeeSchedulePage extends StatefulWidget {
  const EmployeeSchedulePage({super.key});
  @override
  State<EmployeeSchedulePage> createState() => _State();
}

class _State extends State<EmployeeSchedulePage> {
  final search = TextEditingController();
  late final JsonApiClient api;
  late final EmployeeScheduleRepository repo;
  ScheduleActions? actions;
  ScheduleLookups? options;
  EmployeeScheduleResult data = const EmployeeScheduleResult(
    total: 0,
    page: 1,
    pageSize: 30,
    items: [],
  );
  bool loading = true;
  String? message;
  bool error = false;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = EmployeeScheduleRepository(api);
    init();
  }

  @override
  void dispose() {
    search.dispose();
    disposeTimeApiClient(api);
    super.dispose();
  }

  void notice(String x, bool e) {
    if (mounted) {
      setState(() {
        message = x;
        error = e;
      });
    }
  }

  Future<void> init() async {
    try {
      final x = await Future.wait([repo.actions(), repo.lookups()]);
      final a = x[0] as ScheduleActions;
      if (!a.view) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      setState(() {
        actions = a;
        options = x[1] as ScheduleLookups;
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
      final x = await repo.list(
        search: search.text,
        page: page,
        pageSize: timePageSize,
      );
      if (mounted) setState(() => data = x);
    } catch (e) {
      notice(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> form(String mode, {EmployeeScheduleRow? row}) async {
    final o = options!;
    int? employee = row?.employeeId, group = row?.groupId, pattern, shift;
    bool off = false;
    var date = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var reason = '';
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(
            mode == 'assign'
                ? 'จัดพนักงานเข้ากลุ่ม'
                : mode == 'rotate'
                ? 'กำหนด Rotation ให้กลุ่ม'
                : 'ปรับตารางเฉพาะวัน',
          ),
          content: SizedBox(
            width: 600,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mode != 'rotate')
                    drop(
                      'พนักงาน *',
                      employee,
                      o.employees,
                      (v) => set(() => employee = v),
                    ),
                  if (mode != 'override') ...[
                    const SizedBox(height: 12),
                    drop(
                      'กลุ่มตาราง *',
                      group,
                      o.groups,
                      (v) => set(() => group = v),
                    ),
                  ],
                  if (mode == 'rotate') ...[
                    const SizedBox(height: 12),
                    drop(
                      'รูปแบบหมุนกะ *',
                      pattern,
                      o.patterns,
                      (v) => set(() => pattern = v),
                    ),
                  ],
                  if (mode == 'override') ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('กำหนดเป็นวันหยุด'),
                      value: off,
                      onChanged: (v) => set(() => off = v!),
                    ),
                    if (!off)
                      drop(
                        'กะทำงาน *',
                        shift,
                        o.shifts,
                        (v) => set(() => shift = v),
                      ),
                  ],
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: date,
                        firstDate: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                      );
                      if (picked != null) set(() => date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันที่เริ่มใช้ *',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(scheduleDate(date)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'เหตุผล *'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'กรุณาระบุเหตุผล' : null,
                    onChanged: (v) => reason = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(c, true);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (mode == 'assign') {
        await repo.assign(
          employeeId: employee!,
          groupId: group!,
          date: date,
          reason: reason,
        );
      }
      if (mode == 'rotate') {
        await repo.rotate(
          groupId: group!,
          patternId: pattern!,
          date: date,
          reason: reason,
        );
      }
      if (mode == 'override') {
        await repo.override(
          employeeId: employee!,
          date: date,
          dayOff: off,
          shiftId: shift,
          reason: reason,
        );
      }
      await load(page: data.page);
      notice('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Widget drop(
    String label,
    int? value,
    List<ScheduleOption> items,
    ValueChanged<int?> change,
  ) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (x) => DropdownMenuItem(
            value: x.id,
            child: Text(
              '${x.code} — ${x.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    validator: (v) => v == null ? 'กรุณาเลือกข้อมูล' : null,
    onChanged: change,
  );
  @override
  Widget build(BuildContext context) {
    final caption = actions?.caption ?? 'จัดตารางพนักงาน';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.employeeSchedules,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: actions?.edit == true
                            ? () => form('assign')
                            : null,
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('จัดเข้ากลุ่ม'),
                      ),
                      OutlinedButton.icon(
                        onPressed: actions?.edit == true
                            ? () => form('rotate')
                            : null,
                        icon: const Icon(Icons.autorenew),
                        label: const Text('กำหนด Rotation'),
                      ),
                      OutlinedButton.icon(
                        onPressed: actions?.edit == true
                            ? () => form('override')
                            : null,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('ปรับตารางเฉพาะวัน'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    onSubmitted: (_) => load(),
                    decoration: InputDecoration(
                      labelText: 'ค้นหาพนักงานหรือกลุ่ม',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () => load(),
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : data.items.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : ListView.separated(
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
                                  title: Text(
                                    '${x.employeeCode} — ${x.fullName}',
                                  ),
                                  subtitle: Text(
                                    x.groupName == null
                                        ? 'ยังไม่มีกลุ่ม'
                                        : '${x.groupCode} — ${x.groupName}',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'จัดเข้ากลุ่ม',
                                    onPressed: actions?.edit == true
                                        ? () => form('assign', row: x)
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: data.page > 1
                            ? () => load(page: data.page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('หน้า ${data.page}'),
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
                error: error,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}
