import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/pm_api.dart';

class PmPlansPage extends StatelessWidget {
  const PmPlansPage({super.key});
  @override
  Widget build(BuildContext c) => _List(
    title: 'แผนและรอบเวลา PM',
    menu: 'pmPlans',
    future: PmApi().plans,
    name: 'planName',
  );
}

class PmChecklistsPage extends StatelessWidget {
  const PmChecklistsPage({super.key});
  @override
  Widget build(BuildContext c) => _List(
    title: 'รายการตรวจเช็กมาตรฐาน',
    menu: 'pmChecklists',
    future: PmApi().checklists,
    name: 'checklistName',
  );
}

class PmCalendarPage extends StatefulWidget {
  const PmCalendarPage({super.key});
  @override
  State<PmCalendarPage> createState() => _CalendarState();
}

class _CalendarState extends State<PmCalendarPage> {
  final api = PmApi();
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
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.event_available),
              label: const Text('สร้างงานตามรอบ'),
            ),
          ),
          Expanded(
            child: _Rows(future: api.workOrders(''), name: 'planNameSnapshot'),
          ),
        ],
      ),
    ),
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
