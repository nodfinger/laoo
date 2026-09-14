import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'attendance_events_repository.dart';

class AttendanceEventsPage extends StatefulWidget {
  const AttendanceEventsPage({super.key});

  @override
  State<AttendanceEventsPage> createState() => _AttendanceEventsPageState();
}

class _AttendanceEventsPageState extends State<AttendanceEventsPage> {
  static const _pageSize = 30;
  final _employee = TextEditingController();
  final _deviceCode = TextEditingController();
  final _sourceCode = TextEditingController();
  late final JsonApiClient _api;
  late final AttendanceEventsRepository _repository;
  late DateTime _fromDate;
  late DateTime _toDate;
  Map<String, dynamic>? _actions;
  List<Map<String, dynamic>> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  String? _message;
  bool _messageError = false;
  bool _routeFilterInitialized = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repository = AttendanceEventsRepository(_api);
    final today = DateUtils.dateOnly(timeUiTokens.businessDate);
    _fromDate = today;
    _toDate = today;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeFilterInitialized) return;
    _routeFilterInitialized = true;
    final parameters = GoRouterState.of(context).uri.queryParameters;
    _fromDate = _parseDate(parameters['fromDate']) ?? _fromDate;
    _toDate = _parseDate(parameters['toDate']) ?? _fromDate;
    _employee.text = parameters['employee'] ?? '';
    if (!_initialized) {
      _initialized = true;
      _initialize();
    }
  }

  @override
  void dispose() {
    _employee.dispose();
    _deviceCode.dispose();
    _sourceCode.dispose();
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final actions = await _repository.actions();
      if (actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      }
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
        fromDateTime: _fromDate,
        toDateTime: _toDate.add(const Duration(days: 1)).subtract(
          const Duration(microseconds: 1),
        ),
        employee: _employee.text,
        deviceCode: _deviceCode.text,
        sourceCode: _sourceCode.text,
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
    _deviceCode.clear();
    _sourceCode.clear();
    final today = DateUtils.dateOnly(timeUiTokens.businessDate);
    setState(() {
      _fromDate = today;
      _toDate = today;
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

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption'] as String? ?? '';
    const pageSize = _pageSize;
    final pageCount = _total == 0 ? 1 : (_total / pageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.attendanceEvents,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: _api,
              menuCode: TimeMenuCodes.attendanceEvents,
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
                  child: TextField(
                    controller: _deviceCode,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(labelText: 'รหัสที่เครื่อง'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _sourceCode,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(labelText: 'รหัสแหล่งข้อมูล'),
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
              pageSize: pageSize,
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
      readOnly: true,
      initialValue: _dateText(value),
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
          title: Text('${item['employeeCode']} - ${item['fullName']}'),
          subtitle: Text(
            '${_dateTimeText(item['eventDateTime'])}\n'
            'รหัสเครื่อง: ${item['deviceCode']}  |  แหล่งข้อมูล: ${item['sourceCode']}\n'
            'รหัส Event: ${item['sourceEventId']}  |  นำเข้า: ${_dateTimeText(item['importedDateTime'])}',
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
          DataColumn(label: Text('วันเวลา')),
          DataColumn(label: Text('รหัสที่เครื่อง')),
          DataColumn(label: Text('รหัสพนักงาน')),
          DataColumn(label: Text('ชื่อพนักงาน')),
          DataColumn(label: Text('แหล่งข้อมูล')),
          DataColumn(label: Text('รหัส Event ต้นทาง')),
          DataColumn(label: Text('เวลานำเข้า')),
        ],
        rows: [
          for (var index = 0; index < _items.length; index++)
            DataRow(
              cells: [
                DataCell(Text('${(_page - 1) * _pageSize + index + 1}')),
                DataCell(Text(_dateTimeText(_items[index]['eventDateTime']))),
                DataCell(Text('${_items[index]['deviceCode']}')),
                DataCell(Text('${_items[index]['employeeCode']}')),
                DataCell(Text('${_items[index]['fullName']}')),
                DataCell(Text('${_items[index]['sourceCode']}')),
                DataCell(Text('${_items[index]['sourceEventId']}')),
                DataCell(Text(_dateTimeText(_items[index]['importedDateTime']))),
              ],
            ),
        ],
      ),
    ),
  );

  static String _dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static DateTime? _parseDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    return parsed == null ? null : DateUtils.dateOnly(parsed);
  }

  static String _dateTimeText(Object? value) {
    final dateTime = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    return dateTime == null
        ? '-'
        : '${_dateText(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
