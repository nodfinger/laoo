import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'attendance_summary_repository.dart';

class AttendanceSummaryPage extends StatefulWidget {
  const AttendanceSummaryPage({super.key});

  @override
  State<AttendanceSummaryPage> createState() => _AttendanceSummaryPageState();
}

class _AttendanceSummaryPageState extends State<AttendanceSummaryPage> {
  final _employee = TextEditingController();
  late final JsonApiClient _api;
  late final AttendanceSummaryRepository _repository;
  late DateTime _fromDate;
  late DateTime _toDate;
  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _organizationUnits = const [];
  int? _branchId;
  int? _divisionOrgUnitId;
  int? _departmentOrgUnitId;
  Map<String, dynamic>? _actions;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repository = AttendanceSummaryRepository(_api);
    final today = DateUtils.dateOnly(timeUiTokens.businessDate);
    _fromDate = DateTime(today.year, today.month, 1);
    _toDate = today;
    _initialize();
  }

  @override
  void dispose() {
    _employee.dispose();
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final actions = await _repository.actions();
      final organizationUnits = await _repository.organizationUnits();
      final branches = await _repository.branches();
      if (actions['view'] != true) throw StateError('ไม่มีสิทธิ์ดูรายงานนี้');
      if (mounted) {
        setState(() {
          _actions = actions;
          _branches = branches;
          _organizationUnits = organizationUnits;
        });
      }
      await _load();
    } catch (error) {
      _show(timeErrorText(error));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _repository.list(
        fromWorkDate: _fromDate,
        toWorkDate: _toDate,
        employee: _employee.text,
        branchId: _branchId,
        divisionOrgUnitId: _divisionOrgUnitId,
        departmentOrgUnitId: _departmentOrgUnitId,
      );
      if (mounted) setState(() => _items = items);
    } catch (error) {
      _show(timeErrorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) => setState(() => _message = message);

  void _clear() {
    final today = DateUtils.dateOnly(timeUiTokens.businessDate);
    _employee.clear();
    setState(() {
      _fromDate = DateTime(today.year, today.month, 1);
      _toDate = today;
      _branchId = null;
      _divisionOrgUnitId = null;
      _departmentOrgUnitId = null;
    });
    _load();
  }

  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _fromDate = selected;
        if (_toDate.isBefore(selected)) _toDate = selected;
      } else {
        _toDate = selected;
        if (_fromDate.isAfter(selected)) _fromDate = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption']?.toString() ?? '';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.attendanceSummaryReport,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: _api,
              menuCode: TimeMenuCodes.attendanceSummaryReport,
              caption: caption,
            ),
            filter: Wrap(
              spacing: timeUiTokens.itemSpacing,
              runSpacing: timeUiTokens.itemSpacing,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _dateField('ตั้งแต่วันที่', _fromDate, () => _pickDate(true)),
                _dateField('ถึงวันที่', _toDate, () => _pickDate(false)),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    value: _branchId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'สาขา'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      for (final branch in _branches)
                        DropdownMenuItem<int?>(
                          value: (branch['branchId'] as num).toInt(),
                          child: Text(
                            '${branch['branchCode']} - ${branch['branchName']}',
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _branchId = value),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _employee,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      labelText: 'พนักงาน',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    value: _divisionOrgUnitId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ฝ่าย'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      for (final unit in _organizationUnits.where(
                        (item) => item['unitType'] == 'DIV',
                      ))
                        DropdownMenuItem<int?>(
                          value: (unit['orgUnitId'] as num).toInt(),
                          child: Text('${unit['unitCode']} - ${unit['name']}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _divisionOrgUnitId = value),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    value: _departmentOrgUnitId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'แผนก'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      for (final unit in _organizationUnits.where(
                        (item) => item['unitType'] == 'DEP',
                      ))
                        DropdownMenuItem<int?>(
                          value: (unit['orgUnitId'] as num).toInt(),
                          child: Text('${unit['unitCode']} - ${unit['name']}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _departmentOrgUnitId = value),
                  ),
                ),
                Wrap(
                  spacing: timeUiTokens.itemSpacing,
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหา'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : _clear,
                      child: const Text('ล้าง Filter'),
                    ),
                  ],
                ),
              ],
            ),
            table: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('ไม่พบผลลงเวลาจากงวดที่ปิดแล้ว'))
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 900
                        ? _cards()
                        : _table(constraints.maxWidth),
                  ),
            pagination: LaooPaginationCard(
              tokens: timeUiTokens.workspace,
              page: 1,
              pageCount: 1,
              pageSize: _items.isEmpty ? 1 : _items.length,
              total: _items.length,
              onPrevious: null,
              onNext: null,
            ),
          ),
          if (_message != null)
            Positioned(
              top: 16,
              right: 16,
              child: buildTimeMessage(
                message: _message!,
                error: true,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) =>
      SizedBox(
        width: 170,
        child: TextFormField(
          key: ValueKey('$label-${value.toIso8601String()}'),
          initialValue: _date(value),
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
      );

  Widget _cards() => ListView.separated(
    padding: timeUiTokens.cardPadding,
    itemCount: _items.length,
    separatorBuilder: (_, _) => SizedBox(height: timeUiTokens.itemSpacing),
    itemBuilder: (_, index) {
      final item = _items[index];
      return Card(
        child: ListTile(
          title: Text('${item['employeeCode']} - ${item['fullName']}'),
          subtitle: Text(
            'วันทำงาน ${item['workDayCount']} วัน | ครบ ${item['completeDayCount']} | ค้าง ${item['unresolvedDayCount']}\n'
            'ตามกะ ${_minutes(item['scheduledWorkMinutes'])} | ทำงาน ${_minutes(item['actualWorkMinutes'])} | สาย ${_minutes(item['lateMinutes'])} | ออกก่อน ${_minutes(item['earlyMinutes'])}',
          ),
        ),
      );
    },
  );

  Widget _table(double width) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: width),
      child: LaooWorkspaceDataTable(
        tokens: timeUiTokens.workspace,
        headingRowColor: WidgetStatePropertyAll(
          timeUiTokens.primaryColor.withValues(alpha: .10),
        ),
        columns: const [
          DataColumn(label: Text('ลำดับ')),
          DataColumn(label: Text('รหัสพนักงาน')),
          DataColumn(label: Text('ชื่อพนักงาน')),
          DataColumn(label: Text('วันทำงาน')),
          DataColumn(label: Text('ครบ')),
          DataColumn(label: Text('ค้าง')),
          DataColumn(label: Text('ตามกะ')),
          DataColumn(label: Text('ทำงาน')),
          DataColumn(label: Text('สาย')),
          DataColumn(label: Text('ออกก่อน')),
        ],
        rows: [
          for (var index = 0; index < _items.length; index++)
            DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text('${_items[index]['employeeCode']}')),
                DataCell(Text('${_items[index]['fullName']}')),
                DataCell(Text('${_items[index]['workDayCount']}')),
                DataCell(Text('${_items[index]['completeDayCount']}')),
                DataCell(Text('${_items[index]['unresolvedDayCount']}')),
                DataCell(Text(_minutes(_items[index]['scheduledWorkMinutes']))),
                DataCell(Text(_minutes(_items[index]['actualWorkMinutes']))),
                DataCell(Text(_minutes(_items[index]['lateMinutes']))),
                DataCell(Text(_minutes(_items[index]['earlyMinutes']))),
              ],
            ),
        ],
      ),
    ),
  );

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _minutes(Object? value) =>
      '${(value as num?)?.toInt() ?? 0} นาที';
}
