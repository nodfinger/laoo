import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';

class BranchHolidayCalendarPage extends StatefulWidget {
  const BranchHolidayCalendarPage({super.key});
  @override
  State<BranchHolidayCalendarPage> createState() =>
      _BranchHolidayCalendarPageState();
}

class _BranchHolidayCalendarPageState extends State<BranchHolidayCalendarPage> {
  late final JsonApiClient api;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> calendars = [];
  List<Map<String, dynamic>> items = [];
  int? branchId;
  bool loading = true;
  String? message;
  bool messageError = false;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    _init();
  }

  @override
  void dispose() {
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final a = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars/assignments/actions') as Map,
      );
      final b = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars/branches') as Map,
      );
      final c = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars') as Map,
      );
      if (a['view'] != true) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      branches = (b['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      calendars = (c['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['isActive'] == true)
          .toList();
      if (mounted) setState(() => actions = a);
      await load();
    } catch (e) {
      show(timeErrorText(e), true);
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final q = <String, String>{
        'page': '1',
        'pageSize': '30',
        if (branchId != null) 'branchId': '$branchId',
      };
      final x = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars/assignments', query: q)
            as Map,
      );
      if (mounted)
        setState(
          () => items = (x['items'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
    } catch (e) {
      show(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void show(String x, bool error) {
    if (mounted)
      setState(() {
        message = x;
        messageError = error;
      });
  }

  Future<void> edit([Map<String, dynamic>? value]) async {
    final x = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssignmentDialog(
        branches: branches,
        calendars: calendars,
        value: value,
      ),
    );
    if (x == null) return;
    try {
      if (value == null) {
        await api.post('/api/time/holiday-calendars/assignments', body: x);
      } else {
        await api.put(
          '/api/time/holiday-calendars/assignments/${value['branchHolidayCalendarAssignmentId']}',
          body: x,
        );
      }
      await load();
      show('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      show(timeErrorText(e), true);
    }
  }

  Future<void> remove(Map<String, dynamic> x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel: '${x['branchCode']} — ${x['calendarName']}',
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(
        '/api/time/holiday-calendars/assignments/${x['branchHolidayCalendarAssignmentId']}',
        query: {'rowVersion': x['rowVersion'].toString()},
      );
      await load();
      show('ลบข้อมูลสำเร็จ', false);
    } catch (e) {
      show(timeErrorText(e), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption']?.toString() ?? 'ปฏิทินวันหยุดสาขา';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.branchHolidayCalendars,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: timeUiTokens.contentMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TimeCaptionCard(
                    api: api,
                    menuCode: TimeMenuCodes.branchHolidayCalendars,
                    caption: caption,
                    trailing: actions?['create'] == true
                        ? FilledButton.icon(
                            onPressed: () => edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่ม'),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: timeUiTokens.cardPadding,
                      child: SizedBox(
                        width: 380,
                        child: DropdownButtonFormField<int?>(
                          value: branchId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'สาขา'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('ทุกสาขา'),
                            ),
                            ...branches.map(
                              (x) => DropdownMenuItem(
                                value: (x['branchId'] as num).toInt(),
                                child: Text(
                                  '${x['branchCode']} — ${x['branchName']}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => branchId = v);
                            load();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              padding: timeUiTokens.cardPadding,
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final x = items[i];
                                return ListTile(
                                  title: Text(
                                    '${x['branchCode']} — ${x['branchName']}',
                                  ),
                                  subtitle: Text(
                                    '${x['calendarCode']} — ${x['calendarName']}\n${x['effectiveFrom']} ถึง ${x['effectiveTo'] ?? 'ไม่กำหนด'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Wrap(
                                    children: [
                                      if (actions?['edit'] == true)
                                        IconButton(
                                          onPressed: () => edit(x),
                                          tooltip: 'แก้ไข',
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      if (actions?['delete'] == true)
                                        IconButton(
                                          onPressed: () => remove(x),
                                          tooltip: 'ลบ',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
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

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({
    required this.branches,
    required this.calendars,
    this.value,
  });
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> calendars;
  final Map<String, dynamic>? value;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  int? branch;
  int? calendar;
  late DateTime from;
  DateTime? to;
  late bool active;
  @override
  void initState() {
    super.initState();
    branch = (widget.value?['branchId'] as num?)?.toInt();
    calendar = (widget.value?['holidayCalendarId'] as num?)?.toInt();
    from =
        DateTime.tryParse(widget.value?['effectiveFrom']?.toString() ?? '') ??
        DateTime.now();
    to = DateTime.tryParse(widget.value?['effectiveTo']?.toString() ?? '');
    active = widget.value?['isActive'] != false;
  }

  Future<void> pick(bool end) async {
    final x = await showDatePicker(
      context: context,
      initialDate: end ? (to ?? from) : from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (x != null)
      setState(() {
        if (end)
          to = x;
        else
          from = x;
      });
  }

  String d(DateTime x) =>
      '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.account_tree_outlined),
        SizedBox(width: 8),
        Text('ปฏิทินวันหยุดสาขา'),
      ],
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('สถานะ'),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
            DropdownButtonFormField<int>(
              value: branch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'สาขา *'),
              items: widget.branches
                  .map(
                    (x) => DropdownMenuItem(
                      value: (x['branchId'] as num).toInt(),
                      child: Text('${x['branchCode']} — ${x['branchName']}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => branch = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: calendar,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ปฏิทินวันหยุด *'),
              items: widget.calendars
                  .map(
                    (x) => DropdownMenuItem(
                      value: (x['holidayCalendarId'] as num).toInt(),
                      child: Text(
                        '${x['calendarCode']} — ${x['calendarName']}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => calendar = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('วันที่เริ่มใช้'),
              subtitle: Text(d(from)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => pick(false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('วันที่สิ้นสุด'),
              subtitle: Text(to == null ? 'ไม่กำหนด' : d(to!)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => pick(true),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () {
          if (branch == null ||
              calendar == null ||
              (to != null && to!.isBefore(from)))
            return;
          Navigator.pop(context, {
            'branchId': branch,
            'holidayCalendarId': calendar,
            'effectiveFrom': d(from),
            'effectiveTo': to == null ? null : d(to!),
            'isActive': active,
            'rowVersion': widget.value?['rowVersion'],
          });
        },
        child: const Text('บันทึก'),
      ),
    ],
  );
}
