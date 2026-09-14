import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'attendance_period_repository.dart';

class AttendancePeriodSchemesPage extends StatefulWidget {
  const AttendancePeriodSchemesPage({super.key});

  @override
  State<AttendancePeriodSchemesPage> createState() =>
      _AttendancePeriodSchemesPageState();
}

class _AttendancePeriodSchemesPageState
    extends State<AttendancePeriodSchemesPage> {
  late final JsonApiClient _api;
  late final AttendancePeriodRepository _repo;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic>? _actions;
  String? _message;
  bool _error = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repo = AttendancePeriodRepository(_api);
    _load();
  }

  @override
  void dispose() {
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final actions = await _repo.actions('schemes');
      final items = await _repo.schemes();
      if (mounted)
        setState(() {
          _actions = actions;
          _items = items;
        });
    } catch (error) {
      _show(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String value, bool error) => setState(() {
    _message = value;
    _error = error;
  });

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SchemeDialog(row: row),
    );
    if (request == null) return;
    try {
      await _repo.saveScheme(
        request,
        id: (row?['attendancePeriodSchemeId'] as num?)?.toInt(),
      );
      await _load();
      _show('บันทึกรูปแบบงวดปิดผลแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _extend(Map<String, dynamic> row) async {
    try {
      await _repo.extendScheme(
        (row['attendancePeriodSchemeId'] as num).toInt(),
      );
      await _load();
      _show('สร้างงวดล่วงหน้าเพิ่มแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel: '${row['schemeCode']} — ${row['schemeName']}',
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteScheme(
        (row['attendancePeriodSchemeId'] as num).toInt(),
        row['rowVersion'] as String,
      );
      await _load();
      _show('ลบรูปแบบงวดปิดผลแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption']?.toString() ?? '';
    return _timePage(
      title: caption,
      menuCode: TimeMenuCodes.attendancePeriodSchemes,
      api: _api,
      message: _message,
      error: _error,
      onClose: () => setState(() => _message = null),
      captionTrailing: _actions?['create'] == true
          ? FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่ม'),
            )
          : null,
      filter: FilledButton.icon(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
        label: const Text('โหลดข้อมูล'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('ไม่พบรูปแบบงวดปิดผล'))
          : ListView.separated(
              padding: timeUiTokens.cardPadding,
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: timeUiTokens.itemSpacing),
              itemBuilder: (_, index) {
                final item = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      '${item['schemeCode']} — ${item['schemeName']}',
                    ),
                    subtitle: Text(
                      '${_pattern(item['patternCode'])} | เริ่มใช้ ${_date(item['effectiveFrom'])}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'ขยายงวด 12 เดือน',
                          onPressed: () => _extend(item),
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                        if (_actions?['edit'] == true)
                          IconButton(
                            tooltip: 'แก้ไข',
                            onPressed: () => _edit(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        if (_actions?['delete'] == true)
                          IconButton(
                            tooltip: 'ลบ',
                            onPressed: () => _delete(item),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      total: _items.length,
    );
  }
}

class AttendancePeriodAssignmentsPage extends StatefulWidget {
  const AttendancePeriodAssignmentsPage({super.key});

  @override
  State<AttendancePeriodAssignmentsPage> createState() =>
      _AttendancePeriodAssignmentsPageState();
}

class _AttendancePeriodAssignmentsPageState
    extends State<AttendancePeriodAssignmentsPage> {
  late final JsonApiClient _api;
  late final AttendancePeriodRepository _repo;
  final Set<int> _selected = {};
  List<Map<String, dynamic>> _schemes = const [];
  List<Map<String, dynamic>> _employees = const [];
  Map<String, dynamic>? _actions;
  int? _schemeId;
  late DateTime _effectiveDate;
  String? _message;
  bool _error = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repo = AttendancePeriodRepository(_api);
    _effectiveDate = DateUtils.dateOnly(timeUiTokens.businessDate);
    _load();
  }

  @override
  void dispose() {
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final actions = await _repo.actions('assignments');
      final schemes = await _repo.schemes();
      final employees = await _repo.employees();
      if (mounted)
        setState(() {
          _actions = actions;
          _schemes = schemes.where((item) => item['isActive'] == true).toList();
          _employees = employees;
          _schemeId ??= _schemes.isEmpty
              ? null
              : (_schemes.first['attendancePeriodSchemeId'] as num).toInt();
        });
    } catch (error) {
      _show(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String value, bool error) => setState(() {
    _message = value;
    _error = error;
  });

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _effectiveDate = selected);
  }

  Future<void> _save() async {
    if (_schemeId == null || _selected.isEmpty) {
      _show('กรุณาเลือกรูปแบบงวดปิดผลและพนักงานอย่างน้อย 1 คน', true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.bulkAssign({
        'attendancePeriodSchemeId': _schemeId,
        'effectiveFrom': periodDate(_effectiveDate),
        'employeeIds': _selected.toList(),
        'reason': null,
      });
      _selected.clear();
      await _load();
      _show('ผูกพนักงานกับงวดแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption']?.toString() ?? '';
    return _timePage(
      title: caption,
      menuCode: TimeMenuCodes.attendancePeriodAssignments,
      api: _api,
      message: _message,
      error: _error,
      onClose: () => setState(() => _message = null),
      captionTrailing: _actions?['create'] == true
          ? FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึกการผูก'),
            )
          : null,
      filter: Wrap(
        spacing: timeUiTokens.itemSpacing,
        runSpacing: timeUiTokens.itemSpacing,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<int>(
              value: _schemeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'รูปแบบงวดปิดผล'),
              items: [
                for (final scheme in _schemes)
                  DropdownMenuItem(
                    value: (scheme['attendancePeriodSchemeId'] as num).toInt(),
                    child: Text(
                      '${scheme['schemeCode']} — ${scheme['schemeName']}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _schemeId = value),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextFormField(
              key: ValueKey(_effectiveDate),
              initialValue: _date(_effectiveDate),
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'วันที่มีผล',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _loading ? null : _load,
            child: const Text('โหลดข้อมูล'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: timeUiTokens.cardPadding,
              itemCount: _employees.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = _employees[index];
                final employeeId = (item['employeeId'] as num).toInt();
                return CheckboxListTile(
                  value: _selected.contains(employeeId),
                  onChanged: (selected) => setState(() {
                    if (selected == true)
                      _selected.add(employeeId);
                    else
                      _selected.remove(employeeId);
                  }),
                  title: Text('${item['employeeCode']} — ${item['fullName']}'),
                  subtitle: Text(
                    item['schemeName'] == null
                        ? 'ยังไม่ผูกงวด'
                        : 'งวดปัจจุบัน: ${item['schemeName']}',
                  ),
                );
              },
            ),
      total: _employees.length,
    );
  }
}

class AttendancePeriodsPage extends StatefulWidget {
  const AttendancePeriodsPage({super.key});

  @override
  State<AttendancePeriodsPage> createState() => _AttendancePeriodsPageState();
}

class _AttendancePeriodsPageState extends State<AttendancePeriodsPage> {
  late final JsonApiClient _api;
  late final AttendancePeriodRepository _repo;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic>? _actions;
  String? _message;
  bool _error = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repo = AttendancePeriodRepository(_api);
    _load();
  }

  @override
  void dispose() {
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final actions = await _repo.actions('');
      final items = await _repo.periods();
      if (mounted)
        setState(() {
          _actions = actions;
          _items = items;
        });
    } catch (error) {
      _show(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String value, bool error) => setState(() {
    _message = value;
    _error = error;
  });

  Future<void> _finalize(Map<String, dynamic> item) async {
    try {
      await _repo.finalize((item['attendancePeriodId'] as num).toInt());
      await _load();
      _show('ปิดงวดแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _review(Map<String, dynamic> item) async {
    final periodId = (item['attendancePeriodId'] as num).toInt();
    try {
      final rows = await _repo.reviews(periodId);
      if (!mounted) return;
      final branchId = await showDialog<int>(
        context: context,
        builder: (_) => TimeActionDialog(
          icon: Icons.fact_check_outlined,
          title: 'รับรองผลสาขา',
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: rows
                  .map(
                    (row) => ListTile(
                      title: Text(row['branchName']?.toString() ?? '-'),
                      subtitle: Text(
                        row['reviewedDate'] == null ? 'รอรับรอง' : 'รับรองแล้ว',
                      ),
                      trailing: row['reviewedDate'] == null
                          ? TextButton(
                              onPressed: () => Navigator.pop(
                                context,
                                (row['branchId'] as num).toInt(),
                              ),
                              child: const Text('รับรอง'),
                            )
                          : const Icon(Icons.check_circle_outline),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
      if (branchId == null) return;
      await _repo.review(periodId, branchId, '');
      await _load();
      _show('รับรองผลสาขาแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _reopen(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => TimeActionDialog(
        icon: Icons.lock_open_outlined,
        title: 'เปิดงวดแก้ไข',
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'เหตุผล *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await _repo.reopen((item['attendancePeriodId'] as num).toInt(), reason);
      await _load();
      _show('เปิดงวดแก้ไขแล้ว', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption']?.toString() ?? '';
    return _timePage(
      title: caption,
      menuCode: TimeMenuCodes.attendancePeriods,
      api: _api,
      message: _message,
      error: _error,
      onClose: () => setState(() => _message = null),
      filter: FilledButton.icon(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
        label: const Text('โหลดข้อมูล'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: timeUiTokens.cardPadding,
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: timeUiTokens.itemSpacing),
              itemBuilder: (_, index) {
                final item = _items[index];
                final finalized = item['statusCode'] == 'FINALIZED';
                return Card(
                  child: ListTile(
                    title: Text(
                      '${item['schemeCode']} — ${item['schemeName']}',
                    ),
                    subtitle: Text(
                      '${_date(item['periodStartDate'])} - ${_date(item['periodEndDate'])}\n'
                      'ผลค้าง ${item['unresolvedCount']} | สาขารอรับรอง ${item['pendingReviewCount']}',
                    ),
                    trailing: Wrap(
                      children: [
                        if (!finalized && _actions?['approve'] == true)
                          IconButton(
                            tooltip: 'รับรองผลสาขา',
                            onPressed: () => _review(item),
                            icon: const Icon(Icons.fact_check_outlined),
                          ),
                        if (!finalized && _actions?['finalize'] == true)
                          IconButton(
                            tooltip: 'ปิดงวด',
                            onPressed: () => _finalize(item),
                            icon: const Icon(Icons.lock_outline),
                          ),
                        if (finalized && _actions?['reopen'] == true)
                          IconButton(
                            tooltip: 'เปิดงวดแก้ไข',
                            onPressed: () => _reopen(item),
                            icon: const Icon(Icons.lock_open_outlined),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      total: _items.length,
    );
  }
}

class _SchemeDialog extends StatefulWidget {
  const _SchemeDialog({this.row});
  final Map<String, dynamic>? row;

  @override
  State<_SchemeDialog> createState() => _SchemeDialogState();
}

class _SchemeDialogState extends State<_SchemeDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _cutOffDay;
  late final TextEditingController _interval;
  late final TextEditingController _anchor;
  late final TextEditingController _customPeriods;
  late String _pattern;
  late DateTime _effectiveDate;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _code = TextEditingController(text: row?['schemeCode']?.toString() ?? '');
    _name = TextEditingController(text: row?['schemeName']?.toString() ?? '');
    _cutOffDay = TextEditingController(
      text: row?['cutOffDay']?.toString() ?? '15',
    );
    _interval = TextEditingController(
      text: row?['intervalCount']?.toString() ?? '14',
    );
    _anchor = TextEditingController(text: row?['anchorDate']?.toString() ?? '');
    _customPeriods = TextEditingController();
    _pattern = row?['patternCode']?.toString() ?? 'CALENDAR_MONTH';
    _effectiveDate = periodDateValue(row?['effectiveFrom']);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _cutOffDay.dispose();
    _interval.dispose();
    _anchor.dispose();
    _customPeriods.dispose();
    super.dispose();
  }

  void _save() {
    final custom = <Map<String, String>>[];
    for (final line in _customPeriods.text.split(RegExp(r'\r?\n'))) {
      final range = line.trim().split('..');
      if (range.length == 2) {
        custom.add({'startDate': range[0].trim(), 'endDate': range[1].trim()});
      }
    }
    Navigator.pop(context, {
      'schemeCode': _code.text,
      'schemeName': _name.text,
      'descriptionText': null,
      'isActive': true,
      'patternCode': _pattern,
      'effectiveFrom': periodDate(_effectiveDate),
      'cutOffDay': int.tryParse(_cutOffDay.text),
      'intervalCount': int.tryParse(_interval.text),
      'intervalUnitCode': 'DAY',
      'anchorDate': _anchor.text.trim().isEmpty ? null : _anchor.text.trim(),
      'branchReviewDueDays': 3,
      'finalizeDueDays': 7,
      'customPeriods': _pattern == 'CUSTOM_CALENDAR' ? custom : null,
      'rowVersion': widget.row?['rowVersion'],
    });
  }

  @override
  Widget build(BuildContext context) => TimeActionDialog(
    icon: Icons.calendar_month_outlined,
    title: widget.row == null ? 'เพิ่มรูปแบบงวดปิดผล' : 'แก้ไขรูปแบบงวดปิดผล',
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          decoration: const InputDecoration(labelText: 'รหัสรูปแบบ *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'ชื่อรูปแบบ *'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _pattern,
          decoration: const InputDecoration(labelText: 'วิธีสร้างงวด'),
          items: const [
            DropdownMenuItem(
              value: 'CALENDAR_MONTH',
              child: Text('เดือนปฏิทิน'),
            ),
            DropdownMenuItem(
              value: 'CUT_OFF_DAY',
              child: Text('แบ่งเดือนตามวันตัด'),
            ),
            DropdownMenuItem(value: 'FIXED_INTERVAL', child: Text('ทุก N วัน')),
            DropdownMenuItem(
              value: 'CUSTOM_CALENDAR',
              child: Text('ปฏิทินกำหนดเอง'),
            ),
          ],
          onChanged: (value) => setState(() => _pattern = value!),
        ),
        if (_pattern == 'CUT_OFF_DAY')
          TextField(
            controller: _cutOffDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'วันตัดงวด'),
          ),
        if (_pattern == 'FIXED_INTERVAL') ...[
          TextField(
            controller: _interval,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'จำนวนวัน'),
          ),
          TextField(
            controller: _anchor,
            decoration: const InputDecoration(
              labelText: 'วันอ้างอิง YYYY-MM-DD',
            ),
          ),
        ],
        if (_pattern == 'CUSTOM_CALENDAR')
          TextField(
            controller: _customPeriods,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'งวดกำหนดเอง (หนึ่งบรรทัด: YYYY-MM-DD..YYYY-MM-DD)',
            ),
          ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(_effectiveDate),
          initialValue: _date(_effectiveDate),
          readOnly: true,
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              initialDate: _effectiveDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (value != null) setState(() => _effectiveDate = value);
          },
          decoration: const InputDecoration(
            labelText: 'วันที่เริ่มใช้',
            suffixIcon: Icon(Icons.calendar_month_outlined),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: _save, child: const Text('บันทึก')),
    ],
  );
}

Widget _timePage({
  required String title,
  required String menuCode,
  required JsonApiClient api,
  required Widget filter,
  required Widget body,
  required int total,
  Widget? captionTrailing,
  String? message,
  required bool error,
  required VoidCallback onClose,
}) => buildTimeWorkspaceShell(
  pageTitle: title,
  activeMenu: menuCode,
  child: Stack(
    children: [
      LaooListWorkspace(
        tokens: timeUiTokens.workspace,
        caption: TimeCaptionCard(
          api: api,
          menuCode: menuCode,
          caption: title,
          trailing: captionTrailing,
        ),
        filter: filter,
        table: body,
        pagination: LaooPaginationCard(
          tokens: timeUiTokens.workspace,
          page: 1,
          pageCount: 1,
          pageSize: total,
          total: total,
          onPrevious: null,
          onNext: null,
        ),
      ),
      if (message != null)
        Positioned(
          top: 16,
          right: 16,
          child: buildTimeMessage(
            message: message,
            error: error,
            onClose: onClose,
          ),
        ),
    ],
  ),
);

String _date(Object? value) {
  final date = value is DateTime
      ? value
      : DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? '-'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _pattern(Object? value) => switch (value) {
  'CALENDAR_MONTH' => 'เดือนปฏิทิน',
  'CUT_OFF_DAY' => 'แบ่งตามวันตัด',
  'FIXED_INTERVAL' => 'ทุก N วัน',
  'CUSTOM_CALENDAR' => 'กำหนดเอง',
  _ => '-',
};
