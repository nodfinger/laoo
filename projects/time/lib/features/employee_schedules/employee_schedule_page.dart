import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
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
  bool cards = false;
  String? message;
  bool error = false;
  bool get canEdit => actions?.screenType == 1 && actions?.edit == true;
  bool get canDelete => actions?.screenType == 1 && actions?.delete == true;
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
      if (a.screenType != 1) {
        throw StateError('ประเภทหน้าจอไม่ตรงกับเมนู กรุณาติดต่อผู้ดูแลระบบ');
      }
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
    if (!canEdit || options == null) return;
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
        builder: (c, set) => TimeActionDialog(
          icon: Icons.calendar_month_outlined,
          title: mode == 'assign'
              ? 'จัดพนักงานเข้ากลุ่ม'
              : mode == 'rotate'
              ? 'กำหนด Rotation ให้กลุ่ม'
              : 'ปรับตารางเฉพาะวัน',
          content: SizedBox(
            width: double.infinity,
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
                    SizedBox(height: timeUiTokens.popupFieldSpacing),
                    drop(
                      'กลุ่มตาราง *',
                      group,
                      o.groups,
                      (v) => set(() => group = v),
                    ),
                  ],
                  if (mode == 'rotate') ...[
                    SizedBox(height: timeUiTokens.popupFieldSpacing),
                    drop(
                      'รูปแบบหมุนกะ *',
                      pattern,
                      o.patterns,
                      (v) => set(() => pattern = v),
                    ),
                  ],
                  if (mode == 'override') ...[
                    SizedBox(height: timeUiTokens.popupFieldSpacing),
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
                  SizedBox(height: timeUiTokens.popupFieldSpacing),
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
                  SizedBox(height: timeUiTokens.popupFieldSpacing),
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

  Future<void> remove(EmployeeScheduleRow row) async {
    if (!canDelete || row.assignmentId == null || row.rowVersion == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel:
            "${row.employeeCode} — ${row.fullName} / ${row.groupName ?? '-'}",
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await repo.deleteAssignment(row.assignmentId!, row.rowVersion!);
      await load(
        page: data.page > 1 && data.items.length == 1
            ? data.page - 1
            : data.page,
      );
      notice('ลบการจัดตารางสำเร็จ', false);
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
  Widget _table() => LaooWorkspaceDataTable(
    tokens: timeUiTokens.workspace,
    headingRowColor: WidgetStatePropertyAll(
      timeUiTokens.primaryColor.withValues(alpha: .10),
    ),
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ'), columnWidth: FixedColumnWidth(112)),
      DataColumn(label: Text('รหัสพนักงาน')),
      DataColumn(label: Text('ชื่อพนักงาน'), columnWidth: FlexColumnWidth()),
      DataColumn(label: Text('รหัสกลุ่ม')),
      DataColumn(label: Text('กลุ่มตาราง')),
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
                  if (canEdit)
                    IconButton(
                      tooltip: 'จัดเข้ากลุ่ม',
                      onPressed: () => form('assign', row: data.items[index]),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (canDelete && data.items[index].assignmentId != null)
                    IconButton(
                      tooltip: 'ลบการจัดกลุ่ม',
                      onPressed: () => remove(data.items[index]),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            DataCell(Text(data.items[index].employeeCode)),
            DataCell(Text(data.items[index].fullName)),
            DataCell(Text(data.items[index].groupCode ?? '-')),
            DataCell(Text(data.items[index].groupName ?? '-')),
          ],
        ),
    ],
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
              padding: timeUiTokens.contentMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TimeCaptionCard(
                    api: api,
                    menuCode: TimeMenuCodes.employeeSchedules,
                    caption: caption,
                    trailing: LaooListCardToggle(
                      tokens: timeUiTokens.workspace,
                      cards: cards,
                      onChanged: (value) => setState(() => cards = value),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LaooFilterCard(
                    tokens: timeUiTokens.workspace,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (canEdit)
                          Wrap(
                            spacing: timeUiTokens.itemSpacing,
                            runSpacing: timeUiTokens.itemSpacing,
                            children: [
                              FilledButton.icon(
                                onPressed: () => form('assign'),
                                icon: const Icon(Icons.group_add_outlined),
                                label: const Text('จัดเข้ากลุ่ม'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => form('rotate'),
                                icon: const Icon(Icons.autorenew),
                                label: const Text('กำหนด Rotation'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => form('override'),
                                icon: const Icon(Icons.edit_calendar_outlined),
                                label: const Text('ปรับตารางเฉพาะวัน'),
                              ),
                            ],
                          ),
                        if (canEdit) SizedBox(height: timeUiTokens.cardSpacing),
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
                      ],
                    ),
                  ),
                  SizedBox(height: timeUiTokens.itemSpacing),
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
                                  title: Text(
                                    '${x.employeeCode} — ${x.fullName}',
                                  ),
                                  subtitle: Text(
                                    x.groupName == null
                                        ? 'ยังไม่มีกลุ่ม'
                                        : '${x.groupCode} — ${x.groupName}',
                                  ),
                                  trailing:
                                      canEdit ||
                                          (canDelete && x.assignmentId != null)
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (canEdit)
                                              IconButton(
                                                tooltip: 'จัดเข้ากลุ่ม',
                                                onPressed: () =>
                                                    form('assign', row: x),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                            if (canDelete &&
                                                x.assignmentId != null)
                                              IconButton(
                                                tooltip: 'ลบการจัดกลุ่ม',
                                                onPressed: () => remove(x),
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                ),
                                              ),
                                          ],
                                        )
                                      : null,
                                );
                              },
                            )
                          : _table(),
                    ),
                  ),
                  SizedBox(height: timeUiTokens.itemSpacing),
                  TimePaginationCard(
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
