import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../time/time_feature_host.dart';
import 'time_correction_repository.dart';

class TimeCorrectionPage extends StatefulWidget {
  const TimeCorrectionPage({
    required this.menuCode,
    required this.mode,
    super.key,
  });
  final String menuCode;
  final String mode;

  @override
  State<TimeCorrectionPage> createState() => _TimeCorrectionPageState();
}

class _TimeCorrectionPageState extends State<TimeCorrectionPage> {
  late final JsonApiClient api;
  late final TimeCorrectionRepository repo;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> items = [];
  int total = 0;
  int page = 1;
  String? status;
  bool cards = false;
  bool loading = true;
  String? message;
  bool messageError = false;

  bool get approval => widget.mode == 'approval';

  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = TimeCorrectionRepository(api, widget.mode);
    status = approval ? 'PENDING' : null;
    initialize();
  }

  @override
  void dispose() {
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      final value = await repo.actions();
      if (value['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      }
      if (mounted) setState(() => actions = value);
      await load();
    } catch (error) {
      showMessage(timeErrorText(error), true);
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> load({int targetPage = 1}) async {
    setState(() => loading = true);
    try {
      final value = await repo.list(
        status: status,
        page: targetPage,
        pageSize: timePageSize,
      );
      if (!mounted) return;
      setState(() {
        items = (value['items'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        total = (value['total'] as num?)?.toInt() ?? 0;
        page = (value['page'] as num?)?.toInt() ?? targetPage;
      });
    } catch (error) {
      showMessage(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String value, bool error) => setState(() {
    message = value;
    messageError = error;
  });

  Future<void> create() async {
    try {
      final lookups = await repo.lookups();
      if (!mounted) return;
      final value = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CorrectionDialog(
          mode: widget.mode,
          lookups: lookups,
          loadSessions: repo.sessions,
        ),
      );
      if (value == null) return;
      final result = await repo.submit(value);
      await load();
      showMessage(
        result['statusCode'] == 'APPROVED'
            ? 'บันทึกและอนุมัติคำขอสำเร็จ'
            : 'ส่งคำขอสำเร็จ',
        false,
      );
    } catch (error) {
      showMessage(timeErrorText(error), true);
    }
  }

  Future<void> open(Map<String, dynamic> row) async {
    try {
      final detail = await repo.get(row['requestId'] as int);
      if (!mounted) return;
      final decision = await showDialog<_DecisionResult>(
        context: context,
        builder: (_) => _RequestDetailDialog(
          value: detail,
          canApprove: approval && actions?['approve'] == true,
          canCancel:
              widget.mode == 'self' &&
              actions?['cancel'] == true &&
              row['statusCode'] == 'PENDING',
        ),
      );
      if (decision == null) return;
      final header = Map<String, dynamic>.from(detail['header'] as Map);
      if (decision.code == 'CANCELLED') {
        await repo.cancel(
          row['requestId'] as int,
          rowVersion: header['rowVersion'] as String,
          reason: decision.reason,
        );
      } else {
        await repo.decide(
          row['requestId'] as int,
          decision: decision.code,
          rowVersion: header['rowVersion'] as String,
          reason: decision.reason,
        );
      }
      await load(targetPage: page);
      showMessage('ดำเนินการคำขอสำเร็จ', false);
    } catch (error) {
      showMessage(timeErrorText(error), true);
    }
  }

  Widget _buildCards() => ListView.separated(
    padding: timeUiTokens.cardPadding,
    itemCount: items.length,
    separatorBuilder: (_, _) => SizedBox(height: timeUiTokens.itemSpacing),
    itemBuilder: (context, index) {
      final row = items[index];
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: timeUiTokens.primaryColor.withValues(alpha: .1),
            foregroundColor: timeUiTokens.primaryColor,
            child: Text('${(page - 1) * timePageSize + index + 1}'),
          ),
          title: Text('${row['employeeCode']} — ${row['employeeName']}'),
          subtitle: Text(
            '${displayDate('${row['workDate']}')} · ${row['reasonName']}\n'
            '${statusText('${row['statusCode']}')}',
          ),
          trailing: IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: () => open(row),
            icon: const Icon(Icons.visibility_outlined),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption'] as String? ?? '';
    final pageCount = total == 0 ? 1 : (total / timePageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: widget.menuCode,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: api,
              menuCode: widget.menuCode,
              caption: caption,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LaooListCardToggle(
                    tokens: timeUiTokens.workspace,
                    cards: cards,
                    onChanged: (value) => setState(() => cards = value),
                  ),
                  if (!approval && actions?['create'] == true)
                    FilledButton.icon(
                      onPressed: create,
                      icon: const Icon(Icons.add),
                      label: const Text('สร้างคำขอ'),
                    ),
                ],
              ),
            ),
            filter: Wrap(
              spacing: timeUiTokens.itemSpacing,
              runSpacing: timeUiTokens.itemSpacing,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'สถานะคำขอ'),
                    items: [
                      if (!approval)
                        const DropdownMenuItem(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                      const DropdownMenuItem(
                        value: 'PENDING',
                        child: Text('รออนุมัติ'),
                      ),
                      const DropdownMenuItem(
                        value: 'APPROVED',
                        child: Text('อนุมัติแล้ว'),
                      ),
                      const DropdownMenuItem(
                        value: 'REJECTED',
                        child: Text('ไม่อนุมัติ'),
                      ),
                      const DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('ยกเลิก'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : () => load(),
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
              ],
            ),
            table: loading
                ? const Center(child: CircularProgressIndicator())
                : cards
                ? _buildCards()
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingTextStyle: timeUiTokens.tableStyle.copyWith(
                            color: timeUiTokens.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                          dataTextStyle: timeUiTokens.tableStyle,
                          dividerThickness: 1,
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: timeUiTokens.borderColor,
                            ),
                            bottom: BorderSide(color: timeUiTokens.borderColor),
                          ),
                          headingRowColor: WidgetStatePropertyAll(
                            timeUiTokens.primaryColor.withValues(alpha: 0.10),
                          ),
                          columns: const [
                            LaooWorkspaceTableColumns.id,
                            DataColumn(label: Text('ดู')),
                            DataColumn(label: Text('วันที่ทำงาน')),
                            DataColumn(label: Text('พนักงาน')),
                            DataColumn(label: Text('เหตุผล')),
                            DataColumn(label: Text('ผู้เริ่มคำขอ')),
                            DataColumn(label: Text('สถานะ')),
                          ],
                          rows: items
                              .map(
                                (row) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        '${(page - 1) * timePageSize + items.indexOf(row) + 1}',
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        onPressed: () => open(row),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(displayDate('${row['workDate']}')),
                                    ),
                                    DataCell(
                                      Text(
                                        '${row['employeeCode']} — ${row['employeeName']}',
                                      ),
                                    ),
                                    DataCell(Text('${row['reasonName']}')),
                                    DataCell(
                                      Text(
                                        row['initiationModeCode'] == 'SELF'
                                            ? 'พนักงาน'
                                            : 'ผู้ดูแลทำแทน',
                                      ),
                                    ),
                                    DataCell(
                                      Text(statusText('${row['statusCode']}')),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
            pagination: LaooPaginationCard(
              tokens: timeUiTokens.workspace,
              page: page,
              pageCount: pageCount,
              pageSize: timePageSize,
              total: total,
              onPrevious: page > 1 ? () => load(targetPage: page - 1) : null,
              onNext: page < pageCount
                  ? () => load(targetPage: page + 1)
                  : null,
            ),
          ),
          if (message != null)
            Positioned(
              right: 16,
              top: 16,
              child: buildTimeMessage(
                message: message!,
                error: messageError,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({
    required this.mode,
    required this.lookups,
    required this.loadSessions,
  });
  final String mode;
  final Map<String, dynamic> lookups;
  final Future<List<Map<String, dynamic>>> Function(int, DateTime) loadSessions;
  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final key = GlobalKey<FormState>();
  final remark = TextEditingController();
  final onBehalfRemark = TextEditingController();
  final evidence = TextEditingController();
  DateTime workDate = timeUiTokens.businessDate;
  TimeOfDay time = TimeOfDay.now();
  int? employeeId;
  int? reasonId;
  int? onBehalfId;
  int? sessionRuleId;
  String endpoint = 'IN';
  final details = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> sessions = [];
  bool sessionsLoading = false;
  String? detailError;

  List<Map<String, dynamic>> lookup(String name) =>
      (widget.lookups[name] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Map<String, dynamic>? selected(List<Map<String, dynamic>> values, int? id) {
    for (final value in values) {
      if (value['id'] == id) return value;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final employees = lookup('employees');
    if (employees.isNotEmpty) employeeId = employees.first['id'] as int;
    loadSessions();
  }

  @override
  void dispose() {
    remark.dispose();
    onBehalfRemark.dispose();
    evidence.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: workDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() => workDate = value);
      await loadSessions();
    }
  }

  Future<void> loadSessions() async {
    final employee = employeeId;
    if (employee == null) return;
    setState(() => sessionsLoading = true);
    try {
      final value = await widget.loadSessions(employee, workDate);
      if (!mounted) return;
      setState(() {
        sessions = value;
        sessionRuleId = value.isEmpty ? null : value.first['id'] as int;
        details.clear();
      });
    } finally {
      if (mounted) setState(() => sessionsLoading = false);
    }
  }

  Future<void> addDetail() async {
    final selected = sessions
        .where((item) => item['id'] == sessionRuleId)
        .firstOrNull;
    if (selected == null) return;
    final value = await showTimePicker(context: context, initialTime: time);
    if (value == null) return;
    setState(() {
      time = value;
      final dayOffset =
          (endpoint == 'OUT'
                  ? selected['outDayOffset']
                  : selected['inDayOffset'])
              as int;
      final requestedDate = workDate.add(Duration(days: dayOffset));
      details.add({
        'attendanceSessionRuleId': sessionRuleId,
        'sessionName': selected['name'],
        'endpointCode': endpoint,
        'originalDateTime': null,
        'requestedDateTime':
            '${dateValue(requestedDate)}T${two(value.hour)}:${two(value.minute)}:00',
      });
      detailError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = lookup('employees');
    final reasons = lookup('adjustmentReasons');
    final proxyReasons = lookup('onBehalfReasons');
    return TimeActionDialog(
      icon: Icons.edit_calendar_outlined,
      title: widget.mode == 'self'
          ? 'คำขอปรับเวลาของฉัน'
          : 'คำขอปรับเวลาแทนพนักงาน',
      maxWidth: 760,
      scrollable: false,
      content: SizedBox(
        width: 760,
        child: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ข้อมูลคำขอ', style: timeUiTokens.sectionStyle),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 350,
                      child: DropdownButtonFormField<int>(
                        initialValue: employeeId,
                        decoration: const InputDecoration(
                          labelText: 'พนักงาน *',
                        ),
                        items: employees
                            .map(
                              (x) => DropdownMenuItem(
                                value: x['id'] as int,
                                child: Text('${x['code']} — ${x['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: widget.mode == 'self'
                            ? null
                            : (value) {
                                employeeId = value;
                                loadSessions();
                              },
                        validator: requiredValue,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: InkWell(
                        onTap: pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'วันที่ทำงาน *',
                            suffixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                          child: Text(displayDate(dateValue(workDate))),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 350,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'เหตุผลปรับเวลา *',
                        ),
                        items: reasons
                            .map(
                              (x) => DropdownMenuItem(
                                value: x['id'] as int,
                                child: Text('${x['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => reasonId = value),
                        validator: requiredValue,
                      ),
                    ),
                    if (widget.mode == 'proxy')
                      SizedBox(
                        width: 350,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'เหตุผลทำแทน *',
                          ),
                          items: proxyReasons
                              .map(
                                (x) => DropdownMenuItem(
                                  value: x['id'] as int,
                                  child: Text('${x['name']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => onBehalfId = value),
                          validator: requiredValue,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('รายการเวลาที่ขอปรับ', style: timeUiTokens.sectionStyle),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: sessionRuleId,
                        decoration: InputDecoration(
                          labelText: 'รอบเวลาตามตารางทำงาน',
                          suffixIcon: sessionsLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        items: sessions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item['id'] as int,
                                child: Text(
                                  '${item['name']} (${item['inTime']}–${item['outTime']})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => sessionRuleId = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        initialValue: endpoint,
                        decoration: const InputDecoration(labelText: 'จุดเวลา'),
                        items: const [
                          DropdownMenuItem(value: 'IN', child: Text('เข้างาน')),
                          DropdownMenuItem(value: 'OUT', child: Text('ออกงาน')),
                        ],
                        onChanged: (value) => endpoint = value ?? 'IN',
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: addDetail,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มเวลา'),
                    ),
                  ],
                ),
                if (detailError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      detailError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (details.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('ยังไม่มีรายการเวลา'),
                  ),
                ...details.asMap().entries.map(
                  (entry) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(
                      '${entry.value['sessionName']} — ${entry.value['endpointCode'] == 'IN' ? 'เข้างาน' : 'ออกงาน'}',
                    ),
                    subtitle: Text(
                      '${entry.value['requestedDateTime']}'.replaceFirst(
                        'T',
                        ' ',
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => details.removeAt(entry.key)),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remark,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        'หมายเหตุการปรับเวลา${selected(reasons, reasonId)?['requireRemark'] == true ? ' *' : ''}',
                  ),
                  validator: (value) =>
                      selected(reasons, reasonId)?['requireRemark'] == true
                      ? requiredText(value)
                      : null,
                ),
                if (widget.mode == 'proxy') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: onBehalfRemark,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText:
                          'หมายเหตุการทำแทน${selected(proxyReasons, onBehalfId)?['requireRemark'] == true ? ' *' : ''}',
                    ),
                    validator: (value) =>
                        selected(proxyReasons, onBehalfId)?['requireRemark'] ==
                            true
                        ? requiredText(value)
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: evidence,
                  decoration: InputDecoration(
                    labelText:
                        'หลักฐานอ้างอิง${selected(reasons, reasonId)?['requireEvidence'] == true || selected(proxyReasons, onBehalfId)?['requireEvidence'] == true ? ' *' : ''}',
                  ),
                  validator: (value) =>
                      selected(reasons, reasonId)?['requireEvidence'] == true ||
                          selected(
                                proxyReasons,
                                onBehalfId,
                              )?['requireEvidence'] ==
                              true
                      ? requiredText(value)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (key.currentState?.validate() != true) return;
            if (details.isEmpty) {
              setState(() => detailError = 'กรุณาเพิ่มรายการเวลา');
              return;
            }
            Navigator.pop(context, {
              'employeeId': widget.mode == 'self' ? null : employeeId,
              'workDate': dateValue(workDate),
              'timeAdjustmentReasonId': reasonId,
              'onBehalfReasonId': widget.mode == 'proxy' ? onBehalfId : null,
              'requestRemark': remark.text.trim(),
              'onBehalfRemark': widget.mode == 'proxy'
                  ? onBehalfRemark.text.trim()
                  : null,
              'evidenceReference': evidence.text.trim(),
              'details': details,
            });
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('ส่งคำขอ'),
        ),
      ],
    );
  }
}

class _RequestDetailDialog extends StatefulWidget {
  const _RequestDetailDialog({
    required this.value,
    required this.canApprove,
    required this.canCancel,
  });
  final Map<String, dynamic> value;
  final bool canApprove;
  final bool canCancel;
  @override
  State<_RequestDetailDialog> createState() => _RequestDetailDialogState();
}

class _RequestDetailDialogState extends State<_RequestDetailDialog> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = Map<String, dynamic>.from(widget.value['header'] as Map);
    final details = (widget.value['details'] as List? ?? const [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    return TimeActionDialog(
      icon: Icons.approval_outlined,
      title: 'คำขอ #${header['requestId']}',
      maxWidth: 760,
      scrollable: false,
      content: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${header['employeeCode']} — ${header['employeeName']}',
              style: timeUiTokens.sectionStyle,
            ),
            Text(
              'วันที่ทำงาน ${displayDate('${header['workDate']}')} · ${header['adjustmentReasonName']}',
            ),
            const SizedBox(height: 12),
            ...details.map(
              (x) => ListTile(
                dense: true,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(
                  '${x['sessionName']} — ${x['endpointCode'] == 'IN' ? 'เข้างาน' : 'ออกงาน'}',
                ),
                subtitle: Text(
                  '${x['requestedDateTime']}'.replaceFirst('T', ' '),
                ),
              ),
            ),
            if (widget.canApprove || widget.canCancel) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  labelText: widget.canCancel
                      ? 'เหตุผลยกเลิก'
                      : 'เหตุผลกรณีไม่อนุมัติ',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        if (widget.canCancel)
          TextButton(
            onPressed: () {
              if (reason.text.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  _DecisionResult('CANCELLED', reason.text.trim()),
                );
              }
            },
            child: const Text('ยกเลิกคำขอ'),
          ),
        if (widget.canApprove)
          TextButton(
            onPressed: () {
              if (reason.text.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  _DecisionResult('REJECTED', reason.text.trim()),
                );
              }
            },
            child: const Text('ไม่อนุมัติ'),
          ),
        if (widget.canApprove)
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, const _DecisionResult('APPROVED', '')),
            icon: const Icon(Icons.check),
            label: const Text('อนุมัติ'),
          ),
      ],
    );
  }
}

class _DecisionResult {
  const _DecisionResult(this.code, this.reason);
  final String code;
  final String reason;
}

String dateValue(DateTime value) =>
    '${value.year}-${two(value.month)}-${two(value.day)}';
String two(int value) => value.toString().padLeft(2, '0');
String displayDate(String value) {
  final parts = value.substring(0, 10).split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : value;
}

String statusText(String value) => switch (value) {
  'PENDING' => 'รออนุมัติ',
  'APPROVED' => 'อนุมัติแล้ว',
  'REJECTED' => 'ไม่อนุมัติ',
  'CANCELLED' => 'ยกเลิก',
  _ => value,
};
String? requiredValue(Object? value) =>
    value == null ? 'กรุณาระบุข้อมูล' : null;
String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;
