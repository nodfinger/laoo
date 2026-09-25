import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_dashboard_api.dart';

class ServiceDashboardPage extends StatefulWidget {
  const ServiceDashboardPage({super.key});
  @override
  State<ServiceDashboardPage> createState() => _ServiceDashboardPageState();
}

class _ServiceDashboardPageState extends State<ServiceDashboardPage> {
  final _api = ServiceDashboardApi();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  late DateTime _to = DateTime.now();
  late DateTime _from = _to.subtract(const Duration(days: 29));
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _data = await _api.load(_from, _to);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _rows(String key) => ((_data[key] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'แดชบอร์ดภาพรวมงานบริการ',
    activeMenu: 'reportsDashboard',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pick(true),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('ตั้งแต่ ${_date(_from)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pick(false),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('ถึง ${_date(_to)}'),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('แสดงผล'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _rows('statuses').map(_kpi).toList(),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (_, box) => box.maxWidth < 900
                      ? Column(
                          children: [
                            _panel('พื้นที่', _rows('locations')),
                            const SizedBox(height: 10),
                            _panel('ภาระงานช่าง', _rows('technicians')),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _panel('พื้นที่', _rows('locations')),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _panel(
                                'ภาระงานช่าง',
                                _rows('technicians'),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    ),
  );
  Widget _kpi(Map<String, dynamic> row) => SizedBox(
    width: 180,
    child: InkWell(
      onTap: () => context.go('/jobs/work-orders?status=${row['code']}'),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_label('${row['code']}')),
              Text(
                '${row['total']}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _pick(bool isFrom) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: isFrom ? _from : _to,
    );
    if (value == null) return;
    setState(() {
      if (isFrom) {
        _from = value;
        if (_from.isAfter(_to)) _to = value;
      } else {
        _to = value;
        if (_to.isBefore(_from)) _from = value;
      }
    });
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  Widget _panel(String title, List<Map<String, dynamic>> rows) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          if (rows.isEmpty)
            const Text('ไม่มีข้อมูล')
          else
            ...rows.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${e['name']}'),
                trailing: Text('${e['total']} งาน'),
              ),
            ),
        ],
      ),
    ),
  );
  String _label(String v) =>
      const {
        'NEW': 'รอรับเรื่อง',
        'RECEIVED': 'รับเรื่องแล้ว',
        'IN_PROGRESS': 'กำลังดำเนินการ',
        'COMPLETED': 'เสร็จสิ้น',
        'CANCELLED': 'ยกเลิก',
      }[v] ??
      v;
}
