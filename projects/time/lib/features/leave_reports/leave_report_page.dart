import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';

class LeaveReportPage extends StatefulWidget {
  const LeaveReportPage({super.key});
  @override
  State<LeaveReportPage> createState() => _LeaveReportPageState();
}

class _LeaveReportPageState extends State<LeaveReportPage> {
  late final JsonApiClient _api;
  DateTime _from = DateUtils.dateOnly(timeUiTokens.businessDate).subtract(const Duration(days: 30));
  DateTime _to = DateUtils.dateOnly(timeUiTokens.businessDate);
  List<Map<String, dynamic>> _items = const [], _employees = const [], _branches = const [], _units = const [], _leaveTypes = const [];
  String? _caption, _message, _status;
  int? _branchId, _divisionId, _departmentId, _employeeId, _leaveTypeId, _page = 1, _total = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _api = createTimeApiClient(); _initialize(); }
  @override
  void dispose() { disposeTimeApiClient(_api); super.dispose(); }

  Future<void> _initialize() async {
    try {
      final actions = Map<String, dynamic>.from(await _api.get('/api/time/leave-report/actions') as Map);
      final lookups = Map<String, dynamic>.from(await _api.get('/api/time/leave-balances/lookups', query: {'mine': 'false'}) as Map);
      if (!mounted) return;
      setState(() { _caption = actions['caption']?.toString(); _employees = _maps(lookups['employees']); _branches = _maps(lookups['branches']); _units = _maps(lookups['units']); _leaveTypes = _maps(lookups['leaveTypes']); });
      await _load();
    } catch (error) { if (mounted) { setState(() { _message = timeErrorText(error); _loading = false; }); } }
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final q = <String, String>{'fromDate': _date(_from), 'toDate': _date(_to), 'page': '$page', 'pageSize': '$timePageSize'};
      if (_branchId != null) q['branchId'] = '$_branchId';
      if (_divisionId != null) q['divisionOrgUnitId'] = '$_divisionId';
      if (_departmentId != null) q['departmentOrgUnitId'] = '$_departmentId';
      if (_employeeId != null) q['employeeId'] = '$_employeeId';
      if (_leaveTypeId != null) q['leaveTypeId'] = '$_leaveTypeId';
      if (_status != null) q['status'] = _status!;
      final result = Map<String, dynamic>.from(await _api.get('/api/time/leave-report', query: q) as Map);
      if (!mounted) return;
      setState(() { _items = _maps(result['items']); _total = (result['total'] as num?)?.toInt() ?? 0; _page = (result['page'] as num?)?.toInt() ?? page; });
    } catch (error) { if (mounted) setState(() => _message = timeErrorText(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pick(bool from) async {
    final selected = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() { if (from) { _from = selected; if (_to.isBefore(selected)) _to = selected; } else { _to = selected; if (_from.isAfter(selected)) _from = selected; } });
  }

  @override
  Widget build(BuildContext context) {
    final caption = _caption ?? '';
    final pageCount = _total == 0 ? 1 : (_total / timePageSize).ceil();
    return buildTimeWorkspaceShell(pageTitle: caption, activeMenu: TimeMenuCodes.leaveReport, child: Stack(children: [
      LaooListWorkspace(
        tokens: timeUiTokens.workspace,
        caption: TimeCaptionCard(api: _api, menuCode: TimeMenuCodes.leaveReport, caption: caption),
        filter: Wrap(spacing: timeUiTokens.itemSpacing, runSpacing: timeUiTokens.itemSpacing, crossAxisAlignment: WrapCrossAlignment.end, children: [
          _dateField('ตั้งแต่วันที่', _from, () => _pick(true)), _dateField('ถึงวันที่', _to, () => _pick(false)),
          _dropdown('สาขา', _branchId, _branches, (v) => setState(() => _branchId = v)),
          _dropdown('ฝ่าย', _divisionId, _units.where((x) => x['type'] == 'DIV').toList(), (v) => setState(() => _divisionId = v)),
          _dropdown('แผนก', _departmentId, _units.where((x) => x['type'] == 'DEP').toList(), (v) => setState(() => _departmentId = v)),
          _dropdown('พนักงาน', _employeeId, _employees, (v) => setState(() => _employeeId = v), width: 240),
          _dropdown('ประเภทการลา', _leaveTypeId, _leaveTypes, (v) => setState(() => _leaveTypeId = v)),
          SizedBox(width: 180, child: DropdownButtonFormField<String?>(initialValue: _status, decoration: const InputDecoration(labelText: 'สถานะคำขอ'), items: const [DropdownMenuItem(value: null, child: Text('ทั้งหมด')), DropdownMenuItem(value: 'PENDING', child: Text('รออนุมัติ')), DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติแล้ว')), DropdownMenuItem(value: 'REJECTED', child: Text('ไม่อนุมัติ')), DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก'))], onChanged: (v) => setState(() => _status = v))),
          FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.search), label: const Text('ค้นหา')),
          OutlinedButton(onPressed: _loading ? null : _clear, child: const Text('ล้าง Filter')),
        ]),
        table: _loading ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? const Center(child: Text('ไม่พบข้อมูลรายงาน')) : LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: constraints.maxWidth), child: LaooWorkspaceDataTable(tokens: timeUiTokens.workspace, headingRowColor: WidgetStatePropertyAll(timeUiTokens.primaryColor.withValues(alpha: .10)), columns: const [LaooWorkspaceTableColumns.id, DataColumn(label: Text('พนักงาน')), DataColumn(label: Text('ประเภทการลา')), DataColumn(label: Text('ได้รับ')), DataColumn(label: Text('ใช้ไป')), DataColumn(label: Text('รออนุมัติ')), DataColumn(label: Text('คงเหลือ'))], rows: List.generate(_items.length, (index) { final x = _items[index]; return DataRow(cells: [DataCell(Text('${((_page ?? 1) - 1) * timePageSize + index + 1}')), DataCell(Text('${x['employeeCode']} — ${x['fullName']}')), DataCell(Text('${x['leaveTypeCode']} — ${x['leaveTypeName']}')), DataCell(Text('${x['granted']}')), DataCell(Text('${x['used']}')), DataCell(Text('${x['pending']}')), DataCell(Text('${x['balance']}'))]); }))))),
        pagination: LaooPaginationCard(tokens: timeUiTokens.workspace, page: _page ?? 1, pageCount: pageCount, pageSize: timePageSize, total: _total ?? 0, onPrevious: (_page ?? 1) > 1 ? () => _load(page: (_page ?? 1) - 1) : null, onNext: (_page ?? 1) < pageCount ? () => _load(page: (_page ?? 1) + 1) : null),
      ),
      if (_message != null) Positioned(top: 16, right: 16, child: buildTimeMessage(message: _message!, error: true, onClose: () => setState(() => _message = null))),
    ]));
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) => SizedBox(width: 170, child: TextFormField(key: ValueKey('$label-${value.toIso8601String()}'), initialValue: _date(value), readOnly: true, onTap: onTap, decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_month_outlined))));
  Widget _dropdown(String label, int? value, List<Map<String, dynamic>> options, ValueChanged<int?> onChanged, {double width = 220}) => SizedBox(width: width, child: DropdownButtonFormField<int?>(key: ValueKey('$label-$value-${options.length}'), initialValue: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: [const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')), ...options.map((x) => DropdownMenuItem<int?>(value: (x['id'] as num).toInt(), child: Text('${x['code']} — ${x['name']}')))], onChanged: onChanged));
  void _clear() { setState(() { _branchId = null; _divisionId = null; _departmentId = null; _employeeId = null; _leaveTypeId = null; _status = null; _from = DateUtils.dateOnly(timeUiTokens.businessDate).subtract(const Duration(days: 30)); _to = DateUtils.dateOnly(timeUiTokens.businessDate); }); _load(); }
  static String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static List<Map<String, dynamic>> _maps(dynamic value) => (value as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList(growable: false);
}
