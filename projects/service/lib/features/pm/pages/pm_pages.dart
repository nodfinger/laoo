import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/pm_api.dart';

class PmPlansPage extends StatefulWidget {
  const PmPlansPage({super.key});
  @override
  State<PmPlansPage> createState() => _PmPlansState();
}

class _PmPlansState extends State<PmPlansPage> {
  final api = PmApi();
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    data = api.plans;
  }

  void refresh() => setState(() => data = api.plans);
  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: 'แผนและรอบเวลา PM',
    activeMenu: 'pmPlans',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: c,
                  builder: (_) => _NewPlanDialog(api),
                );
                if (ok == true) refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มแผน PM'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: data,
              builder: (c, s) {
                if (!s.hasData)
                  return const Center(child: CircularProgressIndicator());
                final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
                if (rows.isEmpty)
                  return const Center(child: Text('ยังไม่มีแผน PM'));
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: c,
                            builder: (_) => _AssetAssignmentDialog(api, r),
                          );
                          if (ok == true) refresh();
                        },
                        leading: const Icon(Icons.settings_suggest),
                        title: Text(r['planName']?.toString() ?? '-'),
                        subtitle: Text(
                          'ประเภท ${r['itemTypeCode'] ?? '-'} • Asset ${r['assetCount'] ?? 0}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.checklist),
                          tooltip: 'ผูก Checklist',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: c,
                              builder: (_) => _PlanChecklistDialog(api, r),
                            );
                            if (ok == true) refresh();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class PmChecklistsPage extends StatefulWidget {
  const PmChecklistsPage({super.key});
  @override
  State<PmChecklistsPage> createState() => _PmChecklistsState();
}

class _PmChecklistsState extends State<PmChecklistsPage> {
  final api = PmApi();
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    data = api.checklists;
  }

  void refresh() => setState(() => data = api.checklists);
  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: 'รายการตรวจเช็กมาตรฐาน',
    activeMenu: 'pmChecklists',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: c,
                  builder: (_) => _NewChecklistDialog(api),
                );
                if (ok == true) refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่ม Checklist'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _Rows(future: data, name: 'checklistName'),
          ),
        ],
      ),
    ),
  );
}

class PmCalendarPage extends StatefulWidget {
  const PmCalendarPage({
    super.key,
    this.menuCode = '16003',
    this.routeName = 'pmCalendar',
    this.pageTitle = 'ปฏิทินงานบำรุงรักษา',
    this.portalSchedule = false,
  });
  final String menuCode;
  final String routeName;
  final String pageTitle;
  final bool portalSchedule;
  @override
  State<PmCalendarPage> createState() => _CalendarState();
}

class _CalendarState extends State<PmCalendarPage> {
  final api = PmApi();
  late Future<Map<String, dynamic>> data;
  String status = '';
  @override
  void initState() {
    super.initState();
    data = api.workOrders(
      status: status,
      portalSchedule: widget.portalSchedule,
    );
  }

  void refresh() => setState(
    () => data = api.workOrders(
      status: status,
      portalSchedule: widget.portalSchedule,
    ),
  );
  Future<void> open(Map row) async {
    final id = (row['pmWorkOrderId'] as num).toInt();
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PmWorkDialog(api, id, portalSchedule: widget.portalSchedule),
    );
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: widget.pageTitle,
    activeMenu: widget.routeName,
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('รอดำเนินการ'),
                    ),
                    DropdownMenuItem(
                      value: 'IN_PROGRESS',
                      child: Text('กำลังดำเนินการ'),
                    ),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('เสร็จสิ้น'),
                    ),
                    DropdownMenuItem(value: 'SKIPPED', child: Text('ข้าม')),
                  ],
                  onChanged: (value) {
                    status = value ?? '';
                    refresh();
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await api.generate(portalSchedule: widget.portalSchedule);
                  refresh();
                },
                icon: const Icon(Icons.event_available),
                label: const Text('สร้างงานตามรอบ'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: data,
              builder: (c, s) {
                if (!s.hasData)
                  return const Center(child: CircularProgressIndicator());
                final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
                if (rows.isEmpty)
                  return const Center(child: Text('ยังไม่มีงาน PM'));
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        onTap: () => open(r),
                        leading: const Icon(Icons.build_circle_outlined),
                        title: Text(r['planNameSnapshot']?.toString() ?? '-'),
                        subtitle: Text(
                          '${r['itemSnapshot'] ?? '-'}\n${r['locationSnapshot'] ?? '-'}${r['residentNames'] == null ? '' : '\nผู้พักอาศัย: ${r['residentNames']}'}\nกำหนด ${r['dueDate'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Text(r['statusCode']?.toString() ?? '-'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PmWorkDialog extends StatefulWidget {
  const _PmWorkDialog(this.api, this.id, {this.portalSchedule = false});
  final PmApi api;
  final int id;
  final bool portalSchedule;
  @override
  State<_PmWorkDialog> createState() => _PmWorkDialogState();
}

class _PmWorkDialogState extends State<_PmWorkDialog> {
  late Future<Map<String, dynamic>> data;
  final result = TextEditingController();
  bool saving = false;
  @override
  void initState() {
    super.initState();
    data = widget.api.workOrder(
      widget.id,
      portalSchedule: widget.portalSchedule,
    );
  }

  Future<void> action(String value) async {
    if (value != 'start' && result.text.trim().isEmpty) return;
    setState(() => saving = true);
    await widget.api.action(
      widget.id,
      value,
      value == 'start' ? null : result.text.trim(),
      widget.portalSchedule,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('รายละเอียดงาน PM'),
    content: SizedBox(
      width: 620,
      child: FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (c, s) {
          if (!s.hasData)
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          final work = Map<String, dynamic>.from(s.data!['workOrder'] as Map);
          final checks = ((s.data!['checks'] as List?) ?? []).cast<Map>();
          final status = work['statusCode']?.toString() ?? '';
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  work['planNameSnapshot']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(work['itemSnapshot']?.toString() ?? '-'),
                Text(work['locationSnapshot']?.toString() ?? '-'),
                if (work['residentNames'] != null)
                  Text('ผู้พักอาศัย: ${work['residentNames']}'),
                Text('กำหนด: ${work['dueDate'] ?? '-'}'),
                const Divider(),
                ...checks.map(
                  (x) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: x['isChecked'] == true,
                    onChanged: status == 'IN_PROGRESS'
                        ? (v) async {
                            x['isChecked'] = v == true;
                            await widget.api.saveChecks(
                              widget.id,
                              checks
                                  .map(
                                    (e) => {
                                      'pmWorkOrderCheckId':
                                          e['pmWorkOrderCheckId'],
                                      'isChecked': e['isChecked'] == true,
                                      'resultNote': e['resultNote'],
                                    },
                                  )
                                  .toList(),
                              portalSchedule: widget.portalSchedule,
                            );
                            if (mounted) setState(() {});
                          }
                        : null,
                    title: Text(x['checkItemSnapshot']?.toString() ?? '-'),
                  ),
                ),
                if (status == 'IN_PROGRESS' || status == 'PENDING')
                  TextField(
                    controller: result,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: status == 'PENDING'
                          ? 'เหตุผลการข้ามงาน (กรอกเมื่อข้าม)'
                          : 'ผลการตรวจ *',
                    ),
                  ),
                if (status == 'COMPLETED' && work['resultDetail'] != null)
                  Text('ผลการตรวจ: ${work['resultDetail']}'),
                if (status == 'SKIPPED' && work['skipReason'] != null)
                  Text('เหตุผลการข้าม: ${work['skipReason']}'),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(c),
        child: const Text('ปิด'),
      ),
      FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (c, s) {
          if (!s.hasData) return const SizedBox();
          final st = (s.data!['workOrder'] as Map)['statusCode'];
          if (st == 'PENDING')
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: saving ? null : () => action('skip'),
                  child: const Text('ข้ามงาน'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: saving ? null : () => action('start'),
                  child: const Text('เริ่มงาน'),
                ),
              ],
            );
          if (st == 'IN_PROGRESS')
            return FilledButton(
              onPressed: saving ? null : () => action('complete'),
              child: const Text('บันทึกปิดงาน'),
            );
          return const SizedBox();
        },
      ),
    ],
  );
}

class _List extends StatelessWidget {
  const _List({
    required this.title,
    required this.menu,
    required this.future,
    required this.name,
  });
  final String title, menu, name;
  final Future<Map<String, dynamic>> future;
  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: title,
    activeMenu: menu,
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: _Rows(future: future, name: name),
    ),
  );
}

class _Rows extends StatelessWidget {
  const _Rows({required this.future, required this.name});
  final Future<Map<String, dynamic>> future;
  final String name;
  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (c, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
      if (rows.isEmpty) return const Center(child: Text('ยังไม่มีข้อมูล'));
      return ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = rows[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: Text(r[name]?.toString() ?? '-'),
              subtitle: Text(
                r['itemTypeCode']?.toString() ??
                    r['locationSnapshot']?.toString() ??
                    '',
              ),
              trailing: Text(
                r['statusCode']?.toString() ??
                    (r['isActive'] == false ? 'ปิด' : 'ใช้งาน'),
              ),
            ),
          );
        },
      );
    },
  );
}

class _AssetAssignmentDialog extends StatefulWidget {
  const _AssetAssignmentDialog(this.api, this.plan);
  final PmApi api;
  final Map plan;
  @override
  State<_AssetAssignmentDialog> createState() => _AssetAssignmentDialogState();
}

class _PlanChecklistDialog extends StatefulWidget {
  const _PlanChecklistDialog(this.api, this.plan);
  final PmApi api;
  final Map plan;
  @override
  State<_PlanChecklistDialog> createState() => _PlanChecklistDialogState();
}

class _PlanChecklistDialogState extends State<_PlanChecklistDialog> {
  late Future<Map<String, dynamic>> all;
  final ids = <int>{};
  @override
  void initState() {
    super.initState();
    all = widget.api.checklists;
    widget.api.planChecklists((widget.plan['pmPlanId'] as num).toInt()).then((
      x,
    ) {
      for (final r in ((x['items'] as List?) ?? []).cast<Map>()) {
        ids.add((r['pmChecklistId'] as num).toInt());
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> save() async {
    await widget.api.setPlanChecklists(
      (widget.plan['pmPlanId'] as num).toInt(),
      ids.toList(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('ผูก Checklist กับแผน PM'),
    content: SizedBox(
      width: 560,
      child: FutureBuilder<Map<String, dynamic>>(
        future: all,
        builder: (c, s) {
          if (!s.hasData)
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
          return SingleChildScrollView(
            child: Column(
              children: rows.map((r) {
                final id = (r['pmChecklistId'] as num).toInt();
                return CheckboxListTile(
                  value: ids.contains(id),
                  onChanged: (v) =>
                      setState(() => v == true ? ids.add(id) : ids.remove(id)),
                  title: Text(r['checklistName']?.toString() ?? '-'),
                  subtitle: Text('${r['itemCount'] ?? 0} รายการตรวจ'),
                );
              }).toList(),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: save, child: const Text('บันทึก Checklist')),
    ],
  );
}

class _AssetAssignmentDialogState extends State<_AssetAssignmentDialog> {
  late Future<Map<String, dynamic>> candidates;
  late Future<Map<String, dynamic>> assigned;
  final ids = <int>{};
  @override
  void initState() {
    super.initState();
    candidates = widget.api.assets(widget.plan['itemTypeCode'].toString());
    assigned = widget.api.planAssets((widget.plan['pmPlanId'] as num).toInt());
    assigned.then((x) {
      for (final a in ((x['items'] as List?) ?? []).cast<Map>()) {
        if (a['isActive'] == true)
          ids.add((a['itemInstanceId'] as num).toInt());
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> save() async {
    await widget.api.setPlanAssets(
      (widget.plan['pmPlanId'] as num).toInt(),
      ids.toList(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text('ผูก Asset: ${widget.plan['planName']}'),
    content: SizedBox(
      width: 700,
      child: FutureBuilder<Map<String, dynamic>>(
        future: candidates,
        builder: (c, s) {
          if (!s.hasData)
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            );
          final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
          return SingleChildScrollView(
            child: Column(
              children: rows.map((a) {
                final id = (a['itemInstanceId'] as num).toInt();
                return CheckboxListTile(
                  value: ids.contains(id),
                  onChanged: (v) =>
                      setState(() => v == true ? ids.add(id) : ids.remove(id)),
                  title: Text(
                    '${a['itemName'] ?? '-'} / ${a['serialNo'] ?? '-'}',
                  ),
                  subtitle: Text(a['locationSnapshot']?.toString() ?? '-'),
                );
              }).toList(),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: save, child: const Text('บันทึก Asset')),
    ],
  );
}

class _NewPlanDialog extends StatefulWidget {
  const _NewPlanDialog(this.api);
  final PmApi api;
  @override
  State<_NewPlanDialog> createState() => _NewPlanDialogState();
}

class _NewPlanDialogState extends State<_NewPlanDialog> {
  final n = TextEditingController();
  String? t;
  String u = 'MONTH';
  int v = 1;
  late Future<Map<String, dynamic>> types;
  @override
  void initState() {
    super.initState();
    types = widget.api.types;
  }

  Future<void> save() async {
    if (n.text.trim().isEmpty || t == null || v < 1) return;
    await widget.api.savePlan({
      'planName': n.text.trim(),
      'itemTypeCode': t,
      'intervalUnit': u,
      'intervalValue': v,
      'startDate': DateTime.now().toIso8601String(),
      'isActive': true,
      'itemInstanceIds': <int>[],
    });
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('เพิ่มแผน PM'),
    content: FutureBuilder<Map<String, dynamic>>(
      future: types,
      builder: (c, s) {
        if (!s.hasData)
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        final x = ((s.data!['items'] as List?) ?? []).cast<Map>();
        return SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: n,
                decoration: const InputDecoration(labelText: 'ชื่อแผน *'),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'ประเภทอุปกรณ์ *'),
                items: x
                    .map(
                      (e) => DropdownMenuItem(
                        value: e['itemTypeCode']?.toString(),
                        child: Text(e['itemTypeCode']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (z) => setState(() => t = z),
              ),
              DropdownButtonFormField<String>(
                value: u,
                items: const [
                  DropdownMenuItem(value: 'DAY', child: Text('วัน')),
                  DropdownMenuItem(value: 'MONTH', child: Text('เดือน')),
                ],
                onChanged: (z) => setState(() => u = z ?? 'MONTH'),
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ทุก N *'),
                onChanged: (z) => v = int.tryParse(z) ?? 0,
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: save, child: const Text('บันทึก')),
    ],
  );
}

class _NewChecklistDialog extends StatefulWidget {
  const _NewChecklistDialog(this.api);
  final PmApi api;
  @override
  State<_NewChecklistDialog> createState() => _NewChecklistDialogState();
}

class _NewChecklistDialogState extends State<_NewChecklistDialog> {
  final n = TextEditingController(), i = TextEditingController();
  Future<void> save() async {
    if (n.text.trim().isEmpty || i.text.trim().isEmpty) return;
    await widget.api.createChecklist({
      'checklistName': n.text.trim(),
      'isActive': true,
      'items': [
        {'text': i.text.trim(), 'required': true},
      ],
    });
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('เพิ่ม Checklist'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: n,
            decoration: const InputDecoration(labelText: 'ชื่อ Checklist *'),
          ),
          TextField(
            controller: i,
            decoration: const InputDecoration(labelText: 'รายการตรวจแรก *'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: save, child: const Text('บันทึก')),
    ],
  );
}
