import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';

class LeaveBalancePage extends StatefulWidget {
  const LeaveBalancePage({required this.mine, super.key});
  final bool mine;

  @override
  State<LeaveBalancePage> createState() => _LeaveBalancePageState();
}

class _LeaveBalancePageState extends State<LeaveBalancePage> {
  final _search = TextEditingController();
  late final JsonApiClient _api;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _employees = const [];
  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _units = const [];
  List<Map<String, dynamic>> _leaveTypes = const [];
  String? _caption;
  String? _message;
  bool _loading = true;
  bool _canGenerate = false;
  bool _generating = false;
  int _page = 1;
  int _total = 0;
  int? _branchId;
  int? _divisionId;
  int? _departmentId;
  int? _employeeId;
  int? _leaveTypeId;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final mine = widget.mine.toString();
      final actions = Map<String, dynamic>.from(await _api.get('/api/time/leave-balances/actions', query: {'mine': mine}) as Map);
      final lookups = Map<String, dynamic>.from(await _api.get('/api/time/leave-balances/lookups', query: {'mine': mine}) as Map);
      if (!mounted) return;
      setState(() {
        _caption = actions['caption']?.toString();
        _canGenerate = actions['generate'] == true;
        _employees = _maps(lookups['employees']);
        _branches = _maps(lookups['branches']);
        _units = _maps(lookups['units']);
        _leaveTypes = _maps(lookups['leaveTypes']);
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _message = timeErrorText(error));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final query = <String, String>{'mine': widget.mine.toString(), 'page': '$page', 'pageSize': '$timePageSize'};
      if (_search.text.trim().isNotEmpty) query['search'] = _search.text.trim();
      if (!widget.mine) {
        if (_branchId != null) query['branchId'] = '$_branchId';
        if (_divisionId != null) query['divisionOrgUnitId'] = '$_divisionId';
        if (_departmentId != null) query['departmentOrgUnitId'] = '$_departmentId';
        if (_employeeId != null) query['employeeId'] = '$_employeeId';
      }
      if (_leaveTypeId != null) query['leaveTypeId'] = '$_leaveTypeId';
      final result = Map<String, dynamic>.from(await _api.get('/api/time/leave-balances', query: query) as Map);
      if (!mounted) return;
      setState(() {
        _items = _maps(result['items']);
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = (result['page'] as num?)?.toInt() ?? page;
      });
    } catch (error) {
      if (mounted) setState(() => _message = timeErrorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => TimeActionDialog(
        icon: Icons.auto_awesome_outlined,
        title: 'ประมวลผลสิทธิ์ลา',
        content: const Text('ระบบจะสร้างสิทธิ์ตามเกณฑ์ที่มีผล และไม่สร้างรายการซ้ำ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ประมวลผล')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _generating = true);
    try {
      final result = Map<String, dynamic>.from(await _api.post('/api/time/leave-balances/generate', body: {}) as Map);
      if (mounted) setState(() => _message = 'ประมวลผลสิทธิ์สำเร็จ ${result['generatedCount']} รายการ');
      await _load(page: _page);
    } catch (error) {
      if (mounted) setState(() => _message = timeErrorText(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _caption ?? '';
    final pageCount = _total == 0 ? 1 : (_total / timePageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: widget.mine ? TimeMenuCodes.myLeaveBalance : TimeMenuCodes.leaveBalances,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: _api,
              menuCode: widget.mine ? TimeMenuCodes.myLeaveBalance : TimeMenuCodes.leaveBalances,
              caption: caption,
              trailing: !widget.mine && _canGenerate
                  ? FilledButton.icon(onPressed: _generating ? null : _generate, icon: const Icon(Icons.auto_awesome_outlined), label: const Text('ประมวลผลสิทธิ์'))
                  : null,
            ),
            filter: Wrap(
              spacing: timeUiTokens.itemSpacing,
              runSpacing: timeUiTokens.itemSpacing,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                if (!widget.mine) _dropdown('สาขา', _branchId, _branches, (value) => setState(() => _branchId = value)),
                if (!widget.mine) _dropdown('ฝ่าย', _divisionId, _units.where((x) => x['type'] == 'DIV').toList(), (value) => setState(() => _divisionId = value)),
                if (!widget.mine) _dropdown('แผนก', _departmentId, _units.where((x) => x['type'] == 'DEP').toList(), (value) => setState(() => _departmentId = value)),
                if (!widget.mine) _dropdown('พนักงาน', _employeeId, _employees, (value) => setState(() => _employeeId = value), width: 240),
                _dropdown('ประเภทการลา', _leaveTypeId, _leaveTypes, (value) => setState(() => _leaveTypeId = value)),
                SizedBox(width: 260, child: TextField(controller: _search, onSubmitted: (_) => _load(), decoration: const InputDecoration(labelText: 'ค้นหา', prefixIcon: Icon(Icons.search)))),
                FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.search), label: const Text('ค้นหา')),
                OutlinedButton(onPressed: _loading ? null : _clearFilters, child: const Text('ล้าง Filter')),
              ],
            ),
            table: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูลสิทธิ์ลา'))
                    : LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: LaooWorkspaceDataTable(
                            tokens: timeUiTokens.workspace,
                            headingRowColor: WidgetStatePropertyAll(timeUiTokens.primaryColor.withValues(alpha: .10)),
                            columns: [
                              LaooWorkspaceTableColumns.id,
                              if (!widget.mine) const DataColumn(label: Text('พนักงาน')),
                              const DataColumn(label: Text('ประเภทการลา')),
                              const DataColumn(label: Text('คงเหลือ'), numeric: true),
                            ],
                            rows: List.generate(_items.length, (index) {
                              final row = _items[index];
                              return DataRow(cells: [
                                DataCell(Text('${(_page - 1) * timePageSize + index + 1}')),
                                if (!widget.mine) DataCell(Text('${row['employeeCode']} — ${row['fullName']}')),
                                DataCell(Text('${row['leaveTypeCode']} — ${row['leaveTypeName']}')),
                                DataCell(Text('${row['balance']} ${row['unitCode'] == 'DAY' ? 'วัน' : 'นาที'}')),
                              ]);
                            }),
                          ),
                        ),
                      )),
            pagination: LaooPaginationCard(
              tokens: timeUiTokens.workspace,
              page: _page,
              pageCount: pageCount,
              pageSize: timePageSize,
              total: _total,
              onPrevious: _page > 1 ? () => _load(page: _page - 1) : null,
              onNext: _page < pageCount ? () => _load(page: _page + 1) : null,
            ),
          ),
          if (_message != null)
            Positioned(top: 16, right: 16, child: buildTimeMessage(message: _message!, error: true, onClose: () => setState(() => _message = null))),
        ],
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<Map<String, dynamic>> options, ValueChanged<int?> onChanged, {double width = 220}) => SizedBox(
        width: width,
        child: DropdownButtonFormField<int?>(
          key: ValueKey('$label-$value-${options.length}'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
            ...options.map((item) => DropdownMenuItem<int?>(value: (item['id'] as num).toInt(), child: Text('${item['code']} — ${item['name']}'))),
          ],
          onChanged: onChanged,
        ),
      );

  void _clearFilters() {
    _search.clear();
    setState(() { _branchId = null; _divisionId = null; _departmentId = null; _employeeId = null; _leaveTypeId = null; });
    _load();
  }

  static List<Map<String, dynamic>> _maps(dynamic value) => (value as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList(growable: false);
}
