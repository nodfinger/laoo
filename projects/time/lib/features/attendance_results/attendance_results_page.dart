import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'attendance_results_repository.dart';

class AttendanceResultsPage extends StatefulWidget {
  const AttendanceResultsPage({super.key});

  @override
  State<AttendanceResultsPage> createState() => _AttendanceResultsPageState();
}

class _AttendanceResultsPageState extends State<AttendanceResultsPage> {
  static const _pageSize = 30;
  final _employee = TextEditingController();
  late final JsonApiClient _api;
  late final AttendanceResultsRepository _repository;
  late DateTime _fromDate;
  late DateTime _toDate;
  String? _statusCode;
  Map<String, dynamic>? _actions;
  List<Map<String, dynamic>> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  String? _message;
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repository = AttendanceResultsRepository(_api);
    final today = DateUtils.dateOnly(timeUiTokens.businessDate);
    _fromDate = today;
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
      if (actions['view'] != true) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      if (mounted) setState(() => _actions = actions);
      await _load();
    } catch (error) {
      _show(timeErrorText(error), true);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final value = await _repository.list(
        fromWorkDate: _fromDate,
        toWorkDate: _toDate,
        employee: _employee.text,
        statusCode: _statusCode,
        page: page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = (value['items'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false);
        _total = (value['total'] as num?)?.toInt() ?? 0;
        _page = (value['page'] as num?)?.toInt() ?? page;
      });
    } catch (error) {
      _show(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _employee.clear();
    final today = DateUtils.dateOnly(timeUiTokens.businessDate);
    setState(() {
      _fromDate = today;
      _toDate = today;
      _statusCode = null;
    });
    _load();
  }

  void _show(String message, bool error) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageError = error;
    });
  }

  Future<void> _pickDate({required bool from}) async {
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

  void _openRaw(Map<String, dynamic> item) {
    final date = _isoDate(item['workDate']);
    final employeeCode = item['employeeCode']?.toString() ?? '';
    context.go(
      '${TimeRoutePaths.attendanceEvents}?employee=${Uri.encodeComponent(employeeCode)}&fromDate=$date&toDate=$date',
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption'] as String? ?? '';
    final pageCount = _total == 0 ? 1 : (_total / _pageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.attendanceResults,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: _api,
              menuCode: TimeMenuCodes.attendanceResults,
              caption: caption,
            ),
            filter: Wrap(
              spacing: timeUiTokens.itemSpacing,
              runSpacing: timeUiTokens.itemSpacing,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _dateField('ตั้งแต่วันที่', _fromDate, () => _pickDate(from: true)),
                _dateField('ถึงวันที่', _toDate, () => _pickDate(from: false)),
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
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _statusCode,
                    decoration: const InputDecoration(labelText: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'COMPLETE', child: Text('ครบถ้วน')),
                      DropdownMenuItem(value: 'UNRESOLVED', child: Text('รอตรวจสอบ')),
                      DropdownMenuItem(value: 'LEAVE', child: Text('ลาเต็มวัน')),
                      DropdownMenuItem(value: 'LEAVE_PARTIAL', child: Text('ลาบางช่วง')),
                      DropdownMenuItem(value: 'DAY_OFF', child: Text('วันหยุด')),
                    ],
                    onChanged: (value) => setState(() => _statusCode = value),
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
                ? const Center(child: Text('ไม่พบข้อมูล'))
                : LayoutBuilder(
                    builder: (context, constraints) => constraints.maxWidth < 900
                        ? _cards()
                        : _table(constraints.maxWidth),
                  ),
            pagination: LaooPaginationCard(
              tokens: timeUiTokens.workspace,
              page: _page,
              pageCount: pageCount,
              pageSize: _pageSize,
              total: _total,
              onPrevious: _page > 1 ? () => _load(page: _page - 1) : null,
              onNext: _page < pageCount ? () => _load(page: _page + 1) : null,
            ),
          ),
          if (_message != null)
            Positioned(
              right: 16,
              top: 16,
              child: buildTimeMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) => SizedBox(
    width: 170,
    child: TextFormField(
      key: ValueKey('${label}_${value.toIso8601String()}'),
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
    itemBuilder: (context, index) {
      final item = _items[index];
      return Card(
        child: ListTile(
          title: Text('${_date(item['workDate'])} | ${item['employeeCode']} - ${item['fullName']}'),
          subtitle: Text(
            '${_status(item['statusCode'])} | กำหนด ${_minutes(item['scheduledWorkMinutes'])} | ทำงาน ${_minutes(item['actualWorkMinutes'])}\n'
            'สาย ${item['lateMinutes']} นาที | ออกก่อน ${item['earlyMinutes']} นาที${item['leaveTypeNames'] == null ? '' : '\nลา: ${item['leaveTypeNames']} ${item['leaveMinutes']} นาที'}${item['unresolvedReason'] == null ? '' : '\n${item['unresolvedReason']}'}',
          ),
          trailing: IconButton(
            tooltip: 'ดูข้อมูล Raw',
            onPressed: () => _openRaw(item),
            icon: const Icon(Icons.fact_check_outlined),
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
          LaooWorkspaceTableColumns.id,
          DataColumn(label: Text('ดู Raw')),
          DataColumn(label: Text('วันที่')),
          DataColumn(label: Text('รหัสพนักงาน')),
          DataColumn(label: Text('ชื่อพนักงาน')),
          DataColumn(label: Text('สถานะ')),
          DataColumn(label: Text('ตามกะ')),
          DataColumn(label: Text('ทำงาน')),
          DataColumn(label: Text('สาย')),
          DataColumn(label: Text('ออกก่อน')),
          DataColumn(label: Text('เหตุผลรอตรวจสอบ')),
        ],
        rows: [
          for (var index = 0; index < _items.length; index++)
            DataRow(
              cells: [
                DataCell(Text('${(_page - 1) * _pageSize + index + 1}')),
                DataCell(
                  IconButton(
                    tooltip: 'ดูข้อมูล Raw',
                    onPressed: () => _openRaw(_items[index]),
                    icon: const Icon(Icons.fact_check_outlined),
                  ),
                ),
                DataCell(Text(_date(_items[index]['workDate']))),
                DataCell(Text('${_items[index]['employeeCode']}')),
                DataCell(Text('${_items[index]['fullName']}')),
                DataCell(Text(_status(_items[index]['statusCode']))),
                DataCell(Text(_minutes(_items[index]['scheduledWorkMinutes']))),
                DataCell(Text(_minutes(_items[index]['actualWorkMinutes']))),
                DataCell(Text('${_items[index]['lateMinutes']} นาที')),
                DataCell(Text('${_items[index]['earlyMinutes']} นาที')),
                DataCell(Text('${_items[index]['unresolvedReason'] ?? '-'}')),
              ],
            ),
        ],
      ),
    ),
  );

  static String _date(Object? value) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _minutes(Object? value) => '${(value as num?)?.toInt() ?? 0} นาที';

  static String _isoDate(Object? value) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? ''
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _status(Object? value) => switch (value) {
    'LEAVE' => 'ลาเต็มวัน',
    'LEAVE_PARTIAL' => 'ลาบางช่วง',
    'COMPLETE' => 'ครบถ้วน',
    'UNRESOLVED' => 'รอตรวจสอบ',
    'DAY_OFF' => 'วันหยุด',
    _ => '-',
  };
}
