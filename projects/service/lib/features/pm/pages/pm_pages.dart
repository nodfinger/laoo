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
            child: _Rows(future: data, name: 'planName'),
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
  const PmCalendarPage({super.key});
  @override
  State<PmCalendarPage> createState() => _CalendarState();
}

class _CalendarState extends State<PmCalendarPage> {
  final api = PmApi();
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    data = api.workOrders('');
  }

  void refresh() => setState(() => data = api.workOrders(''));
  Future<void> open(Map row) async {
    final id = (row['pmWorkOrderId'] as num).toInt();
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PmWorkDialog(api, id),
    );
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: 'ปฏิทินงานบำรุงรักษา',
    activeMenu: 'pmCalendar',
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
                await api.generate();
                refresh();
              },
              icon: const Icon(Icons.event_available),
              label: const Text('สร้างงานตามรอบ'),
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
                        subtitle: Text(r['itemSnapshot']?.toString() ?? '-'),
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
  const _PmWorkDialog(this.api, this.id);
  final PmApi api;
  final int id;
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
    data = widget.api.workOrder(widget.id);
  }

  Future<void> action(String value) async {
    if (value != 'start' && result.text.trim().isEmpty) return;
    setState(() => saving = true);
    await widget.api.action(
      widget.id,
      value,
      value == 'start' ? null : result.text.trim(),
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
                            );
                            if (mounted) setState(() {});
                          }
                        : null,
                    title: Text(x['checkItemSnapshot']?.toString() ?? '-'),
                  ),
                ),
                if (status == 'IN_PROGRESS')
                  TextField(
                    controller: result,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'ผลการตรวจ *'),
                  ),
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
            return FilledButton(
              onPressed: saving ? null : () => action('start'),
              child: const Text('เริ่มงาน'),
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
