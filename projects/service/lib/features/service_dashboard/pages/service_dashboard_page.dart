import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_dashboard_api.dart';

class ServiceDashboardPage extends StatefulWidget {
  const ServiceDashboardPage({super.key, this.api});
  final ServiceDashboardApi? api;
  @override
  State<ServiceDashboardPage> createState() => _ServiceDashboardPageState();
}

class _ServiceDashboardPageState extends State<ServiceDashboardPage> {
  late final ServiceDashboardApi _api = widget.api ?? ServiceDashboardApi();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _loadError;
  String _caption = 'แดชบอร์ดภาพรวมงานบริการ';
  int _requestNumber = 0;
  late DateTime _to = DateTime.now();
  late DateTime _from = _to.subtract(const Duration(days: 29));
  @override
  void initState() {
    super.initState();
    _load();
    _loadCaption();
  }

  Future<void> _loadCaption() async {
    try {
      final caption = await NavigationMenuRepository().resolveMenuName(
        menuCode: '19001',
        routeName: 'reportsDashboard',
        fallback: _caption,
      );
      if (mounted) setState(() => _caption = caption);
    } catch (_) {}
  }

  Future<void> _load() async {
    final requestNumber = ++_requestNumber;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _api.load(_from, _to);
      if (mounted && requestNumber == _requestNumber) {
        setState(() => _data = data);
      }
    } catch (error) {
      if (mounted && requestNumber == _requestNumber) {
        setState(() {
          _data = {};
          _loadError = error is ApiException
              ? 'ไม่สามารถโหลดแดชบอร์ดงานบริการได้\nรายละเอียดเพิ่มเติม: ${error.description ?? error.message}'
              : 'ไม่สามารถโหลดแดชบอร์ดงานบริการได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองอีกครั้ง';
        });
      }
    } finally {
      if (mounted && requestNumber == _requestNumber) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _rows(String key) => ((_data[key] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'reportsDashboard',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(LaooLayout.cardPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_loadError!),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(LaooLayout.cardPadding),
                    child: Wrap(
                      spacing: LaooLayout.cardSpacing,
                      runSpacing: LaooLayout.cardSpacing,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                if (_rows('statuses').isEmpty)
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(LaooLayout.cardPadding),
                      child: Text('ไม่มีงานบริการในช่วงวันที่ที่เลือก'),
                    ),
                  ),
                Wrap(
                  spacing: LaooLayout.cardSpacing,
                  runSpacing: LaooLayout.cardSpacing,
                  children: _rows('statuses').map(_kpi).toList(),
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                LayoutBuilder(
                  builder: (_, box) => box.maxWidth < 900
                      ? Column(
                          children: [
                            _panel('พื้นที่', _rows('locations')),
                            const SizedBox(height: LaooLayout.cardSpacing),
                            _panel('ภาระงานช่าง', _rows('technicians')),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _panel('พื้นที่', _rows('locations')),
                            ),
                            const SizedBox(width: LaooLayout.cardSpacing),
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
    width: MediaQuery.sizeOf(context).width < 500 ? double.infinity : 180,
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
    await _load();
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
