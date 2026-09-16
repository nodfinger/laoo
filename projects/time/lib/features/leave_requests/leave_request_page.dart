import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import 'leave_request_repository.dart';

class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({required this.menuCode, required this.mode, super.key});

  final String menuCode;
  final String mode;

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  late final JsonApiClient _api;
  late final LeaveRequestRepository _repo;
  Map<String, dynamic>? _actions;
  List<Map<String, dynamic>> _items = const [];
  int _total = 0;
  int _page = 1;
  String? _status;
  bool _loading = true;
  String? _message;
  bool _messageError = false;

  bool get _approval => widget.mode == 'approval';

  @override
  void initState() {
    super.initState();
    _api = createTimeApiClient();
    _repo = LeaveRequestRepository(_api, widget.mode);
    _status = _approval ? 'PENDING' : null;
    _initialize();
  }

  @override
  void dispose() {
    disposeTimeApiClient(_api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final actions = await _repo.actions();
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
      final result = await _repo.list(
        status: _status,
        page: page,
        pageSize: timePageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = (result['items'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false);
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = (result['page'] as num?)?.toInt() ?? page;
      });
    } catch (error) {
      _show(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String value, bool error) {
    if (mounted) setState(() {
      _message = value;
      _messageError = error;
    });
  }

  Future<void> _create() async {
    try {
      final lookups = await _repo.lookups();
      if (!mounted) return;
      final body = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LeaveRequestDialog(mode: widget.mode, lookups: lookups),
      );
      if (body == null) return;
      final result = await _repo.submit(body);
      await _load();
      _show(
        result['statusCode'] == 'APPROVED'
            ? 'บันทึกและอนุมัติคำขอเรียบร้อย'
            : 'ส่งคำขอเรียบร้อย',
        false,
      );
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _decide(Map<String, dynamic> row, String decision) async {
    final reason = decision == 'REJECTED'
        ? await _reasonDialog('เหตุผลไม่อนุมัติ')
        : '';
    if (reason == null) return;
    try {
      await _repo.decide(
        row['requestId'] as int,
        decisionCode: decision,
        rowVersion: row['rowVersion'] as String,
        reason: reason,
      );
      await _load(page: _page);
      _show('ดำเนินการคำขอเรียบร้อย', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final reason = await _reasonDialog('เหตุผลยกเลิกคำขอ');
    if (reason == null) return;
    try {
      await _repo.cancel(
        row['requestId'] as int,
        rowVersion: row['rowVersion'] as String,
        reason: reason,
      );
      await _load(page: _page);
      _show('ยกเลิกคำขอเรียบร้อย', false);
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<void> _view(Map<String, dynamic> row) async {
    try {
      final value = await _repo.get(row['requestId'] as int);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _LeaveRequestDetailDialog(value: value),
      );
    } catch (error) {
      _show(timeErrorText(error), true);
    }
  }

  Future<String?> _reasonDialog(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => TimeActionDialog(
        icon: Icons.rate_review_outlined,
        title: title,
        maxWidth: 520,
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'เหตุผล *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final caption = _actions?['caption'] as String? ?? '';
    final pageCount = _total == 0 ? 1 : (_total / timePageSize).ceil();
    final actionColumn = (_approval && _actions?['approve'] == true) ||
        (widget.mode == 'self' && _actions?['cancel'] == true);
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: widget.menuCode,
      child: Stack(children: [
        LaooListWorkspace(
          tokens: timeUiTokens.workspace,
          caption: TimeCaptionCard(
            api: _api,
            menuCode: widget.menuCode,
            caption: caption,
            trailing: !_approval && _actions?['create'] == true
                ? FilledButton.icon(
                    onPressed: _loading ? null : _create,
                    icon: const Icon(Icons.add),
                    label: const Text('สร้างคำขอ'),
                  )
                : null,
          ),
          filter: Wrap(
            spacing: timeUiTokens.itemSpacing,
            runSpacing: timeUiTokens.itemSpacing,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(_status),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'สถานะคำขอ'),
                  items: [
                    if (!_approval) const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    const DropdownMenuItem(value: 'PENDING', child: Text('รออนุมัติ')),
                    const DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติแล้ว')),
                    const DropdownMenuItem(value: 'REJECTED', child: Text('ไม่อนุมัติ')),
                    const DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _status = _approval ? 'PENDING' : null);
                        _load();
                      },
                child: const Text('ล้าง Filter'),
              ),
            ],
          ),
          table: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('ไม่พบคำขอลาในเงื่อนไขที่เลือก'))
                  : LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: LaooWorkspaceDataTable(
                            tokens: timeUiTokens.workspace,
                            headingRowColor: WidgetStatePropertyAll(timeUiTokens.primaryColor.withValues(alpha: .10)),
                            columns: [
                              LaooWorkspaceTableColumns.id,
                              const DataColumn(label: Text('ดู')),
                              const DataColumn(label: Text('พนักงาน')),
                              const DataColumn(label: Text('ประเภทการลา')),
                              const DataColumn(label: Text('ช่วงวันลา')),
                              const DataColumn(label: Text('จำนวน')),
                              const DataColumn(label: Text('ผู้เริ่มคำขอ')),
                              const DataColumn(label: Text('สถานะ')),
                              if (actionColumn) const DataColumn(label: Text('ดำเนินการ')),
                            ],
                            rows: List.generate(_items.length, (index) {
                              final row = _items[index];
                              return DataRow(cells: [
                                DataCell(Text('${(_page - 1) * timePageSize + index + 1}')),
                                DataCell(IconButton(tooltip: 'ดูรายละเอียด', onPressed: () => _view(row), icon: const Icon(Icons.visibility_outlined))),
                                DataCell(Text('${row['employeeCode']} — ${row['fullName']}')),
                                DataCell(Text('${row['leaveTypeName']}')),
                                DataCell(Text('${_date(row['startWorkDate'])} - ${_date(row['endWorkDate'])}')),
                                DataCell(Text('${row['requestedQuantity']} ${row['unitCode'] == 'DAY' ? 'วัน' : 'นาที'}')),
                                DataCell(Text(row['initiationModeCode'] == 'SELF' ? 'พนักงาน' : 'ผู้ดูแลทำแทน')),
                                DataCell(Text(_statusText('${row['statusCode']}'))),
                                if (_approval && _actions?['approve'] == true)
                                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(tooltip: 'อนุมัติ', onPressed: () => _decide(row, 'APPROVED'), icon: Icon(Icons.check_circle_outline, color: timeUiTokens.primaryColor)),
                                    IconButton(tooltip: 'ไม่อนุมัติ', onPressed: () => _decide(row, 'REJECTED'), icon: const Icon(Icons.cancel_outlined, color: Colors.red)),
                                  ]))
                                else if (widget.mode == 'self' && _actions?['cancel'] == true)
                                  DataCell(row['statusCode'] == 'PENDING'
                                      ? TextButton.icon(onPressed: () => _cancel(row), icon: const Icon(Icons.cancel_outlined), label: const Text('ยกเลิก'))
                                      : const SizedBox.shrink()),
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
        if (_message != null) Positioned(
          top: 16,
          right: 16,
          child: buildTimeMessage(message: _message!, error: _messageError, onClose: () => setState(() => _message = null)),
        ),
      ]),
    );
  }
}

class _LeaveRequestDetailDialog extends StatelessWidget {
  const _LeaveRequestDetailDialog({required this.value});
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final header = Map<String, dynamic>.from(value['header'] as Map);
    final details = (value['details'] as List? ?? const [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList(growable: false);
    final decisions = (value['decisions'] as List? ?? const [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList(growable: false);
    return TimeActionDialog(
      icon: Icons.event_note_outlined,
      title: 'รายละเอียดคำขอลา',
      maxWidth: 680,
      scrollable: false,
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${header['employeeCode']} — ${header['fullName']}', style: timeUiTokens.sectionStyle),
            Text('${header['leaveTypeName']} | ${_statusText('${header['statusCode']}')}'),
            const SizedBox(height: 12),
            Text('รายการวันลา', style: timeUiTokens.sectionStyle),
            ...details.map((x) => ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_date(x['workDate'])),
              subtitle: Text(_leaveDetailText(x, '${header['unitCode']}')),
            )),
            if (header['requestRemark'] != null && '${header['requestRemark']}'.isNotEmpty) ...[
              const SizedBox(height: 8), Text('หมายเหตุ: ${header['requestRemark']}'),
            ],
            if (header['onBehalfRemark'] != null && '${header['onBehalfRemark']}'.isNotEmpty) ...[
              const SizedBox(height: 8), Text('หมายเหตุทำแทน: ${header['onBehalfRemark']}'),
            ],
            if (header['onBehalfReasonName'] != null) ...[
              const SizedBox(height: 8), Text('เหตุผลทำแทน: ${header['onBehalfReasonName']}'),
            ],
            if (decisions.isNotEmpty) ...[
              const SizedBox(height: 16), Text('ประวัติการดำเนินการ', style: timeUiTokens.sectionStyle),
              ...decisions.map((x) => ListTile(
                dense: true,
                leading: const Icon(Icons.history_outlined),
                title: Text(_statusText('${x['decisionCode']}')),
                subtitle: x['reason'] == null ? null : Text('${x['reason']}'),
              )),
            ],
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด'))],
    );
  }
}

class _LeaveRequestDialog extends StatefulWidget {
  const _LeaveRequestDialog({required this.mode, required this.lookups});
  final String mode;
  final Map<String, dynamic> lookups;

  @override
  State<_LeaveRequestDialog> createState() => _LeaveRequestDialogState();
}

class _LeaveRequestDialogState extends State<_LeaveRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _remark = TextEditingController();
  final _evidence = TextEditingController();
  final _onBehalfRemark = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  int? _employeeId;
  int? _leaveTypeId;
  int? _onBehalfReasonId;
  int? _startMinute;
  int? _endMinute;

  List<Map<String, dynamic>> _lookup(String name) => (widget.lookups[name] as List? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _from = DateUtils.dateOnly(timeUiTokens.businessDate);
    _to = _from;
    final types = _lookup('leaveTypes');
    final employees = _lookup('employees');
    if (types.isNotEmpty) _leaveTypeId = types.first['LeaveTypeID'] as int?;
    if (employees.isNotEmpty) _employeeId = employees.first['EmployeeID'] as int?;
  }

  @override
  void dispose() {
    _quantity.dispose(); _remark.dispose(); _evidence.dispose(); _onBehalfRemark.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool from}) async {
    final selected = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() {
      if (from) { _from = selected; if (_to.isBefore(selected)) _to = selected; }
      else { _to = selected; if (_from.isAfter(selected)) _from = selected; }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _startMinute : _endMinute;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (current ?? (start ? 480 : 540)) ~/ 60, minute: (current ?? (start ? 480 : 540)) % 60),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final minute = selected.hour * 60 + selected.minute;
      if (start) _startMinute = minute; else _endMinute = minute;
    });
  }

  @override
  Widget build(BuildContext context) {
    final proxy = widget.mode == 'proxy';
    final types = _lookup('leaveTypes');
    final employees = _lookup('employees');
    final reasons = _lookup('onBehalfReasons');
    final selectedType = types.where((item) => item['LeaveTypeID'] == _leaveTypeId).cast<Map<String, dynamic>>().toList();
    final isMinute = selectedType.isNotEmpty && selectedType.first['UnitCode'] == 'MINUTE';
    return TimeActionDialog(
      icon: Icons.event_note_outlined,
      title: proxy ? 'สร้างคำขอลาแทนพนักงาน' : 'สร้างคำขอลาของฉัน',
      maxWidth: 720,
      scrollable: false,
      content: SizedBox(width: 720, child: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('ข้อมูลคำขอลา', style: timeUiTokens.sectionStyle),
          const SizedBox(height: 12),
          if (proxy) ...[
            DropdownButtonFormField<int>(
              value: _employeeId,
              decoration: const InputDecoration(labelText: 'พนักงาน *'),
              items: employees.map((x) => DropdownMenuItem(value: x['EmployeeID'] as int, child: Text('${x['EmployeeCode']} — ${x['FullName']}'))).toList(),
              onChanged: (value) => setState(() => _employeeId = value),
              validator: _required,
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            value: _leaveTypeId,
            decoration: const InputDecoration(labelText: 'ประเภทการลา *'),
            items: types.map((x) => DropdownMenuItem(value: x['LeaveTypeID'] as int, child: Text('${x['LeaveTypeCode']} — ${x['LeaveTypeName']}'))).toList(),
            onChanged: (value) => setState(() {
              _leaveTypeId = value;
              final type = types.where((item) => item['LeaveTypeID'] == value).cast<Map<String, dynamic>>().toList();
              if (type.isNotEmpty && type.first['UnitCode'] == 'MINUTE') {
                _to = _from;
                _startMinute ??= 480;
                _endMinute ??= 540;
              }
            }),
            validator: _required,
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _dateField('เริ่มวันที่ *', _from, () => _pick(from: true)),
            if (!isMinute) _dateField('ถึงวันที่ *', _to, () => _pick(from: false)),
            if (isMinute) ...[
              _timeField('เริ่มเวลา *', _startMinute, () => _pickTime(start: true)),
              _timeField('สิ้นสุดเวลา *', _endMinute, () => _pickTime(start: false)),
              SizedBox(width: 180, child: TextFormField(initialValue: '${(_endMinute ?? 0) - (_startMinute ?? 0)} นาที', readOnly: true, decoration: const InputDecoration(labelText: 'จำนวน'))),
            ] else SizedBox(width: 180, child: TextFormField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'จำนวน *'), validator: _positive)),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _remark, maxLines: 2, decoration: const InputDecoration(labelText: 'หมายเหตุ')),
          const SizedBox(height: 12),
          TextFormField(controller: _evidence, decoration: const InputDecoration(labelText: 'เอกสารอ้างอิง')),
          if (proxy) ...[
            const SizedBox(height: 16), Text('ข้อมูลการทำแทน', style: timeUiTokens.sectionStyle), const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _onBehalfReasonId,
              decoration: const InputDecoration(labelText: 'เหตุผลทำแทน *'),
              items: reasons.map((x) => DropdownMenuItem(value: x['OnBehalfReasonID'] as int, child: Text('${x['ReasonCode']} — ${x['ReasonName']}'))).toList(),
              onChanged: (value) => setState(() => _onBehalfReasonId = value), validator: _required,
            ),
            const SizedBox(height: 12), TextFormField(controller: _onBehalfRemark, maxLines: 2, decoration: const InputDecoration(labelText: 'หมายเหตุการทำแทน')),
          ],
        ])),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, {
              'employeeId': proxy ? _employeeId : null,
              'leaveTypeId': _leaveTypeId,
              'startWorkDate': _dateValue(_from), 'endWorkDate': _dateValue(isMinute ? _from : _to),
              'requestedQuantity': isMinute ? (_endMinute! - _startMinute!) : num.parse(_quantity.text.trim()),
              'startMinute': isMinute ? _startMinute : null,
              'endMinute': isMinute ? _endMinute : null,
              'requestRemark': _remark.text.trim(), 'evidenceReference': _evidence.text.trim(),
              'onBehalfReasonId': proxy ? _onBehalfReasonId : null,
              'onBehalfRemark': proxy ? _onBehalfRemark.text.trim() : null,
            });
          },
          icon: const Icon(Icons.send_outlined), label: const Text('ส่งคำขอ'),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) => SizedBox(width: 190, child: TextFormField(key: ValueKey('$label$value'), initialValue: _date(value), readOnly: true, onTap: onTap, decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_month_outlined))));
  Widget _timeField(String label, int? value, VoidCallback onTap) => SizedBox(width: 150, child: TextFormField(key: ValueKey('$label$value'), initialValue: value == null ? '' : _time(value), readOnly: true, onTap: onTap, validator: (_) => value == null ? 'กรุณาเลือกเวลา' : null, decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule_outlined))));
}

String _date(Object? value) {
  final text = '$value';
  final parts = text.length >= 10 ? text.substring(0, 10).split('-') : const <String>[];
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : text;
}

String _dateValue(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _time(int minute) => '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String _leaveDetailText(Map<String, dynamic> value, String unitCode) {
  final quantity = value['requestedQuantity'];
  if (unitCode != 'MINUTE') return '$quantity วัน';
  final start = (value['startMinute'] as num?)?.toInt();
  final end = (value['endMinute'] as num?)?.toInt();
  if (start == null || end == null) return '$quantity นาที';
  String format(int minute) => '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  return '${format(start)}–${format(end)} · $quantity นาที';
}
String? _required(Object? value) => value == null ? 'กรุณาระบุข้อมูล' : null;
String? _positive(String? value) => (num.tryParse(value ?? '') ?? 0) > 0 ? null : 'กรุณาระบุจำนวนมากกว่า 0';
String _statusText(String value) => switch (value) { 'PENDING' => 'รออนุมัติ', 'APPROVED' => 'อนุมัติแล้ว', 'REJECTED' => 'ไม่อนุมัติ', 'CANCELLED' => 'ยกเลิก', _ => value };
