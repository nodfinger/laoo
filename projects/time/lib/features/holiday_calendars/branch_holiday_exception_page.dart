import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';

class BranchHolidayExceptionPage extends StatefulWidget {
  const BranchHolidayExceptionPage({super.key});
  @override
  State<BranchHolidayExceptionPage> createState() =>
      _BranchHolidayExceptionPageState();
}

class _BranchHolidayExceptionPageState
    extends State<BranchHolidayExceptionPage> {
  late final JsonApiClient api;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> branches = [];
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
        await api.get('/api/time/holiday-calendars/exceptions/actions') as Map,
      );
      final b = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars/branches') as Map,
      );
      if (a['view'] != true) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      branches = (b['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
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
        await api.get('/api/time/holiday-calendars/exceptions', query: q)
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
      builder: (_) => _ExceptionDialog(branches: branches, value: value),
    );
    if (x == null) return;
    try {
      if (value == null) {
        await api.post('/api/time/holiday-calendars/exceptions', body: x);
      } else {
        await api.put(
          '/api/time/holiday-calendars/exceptions/${value['branchHolidayExceptionId']}',
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
        itemLabel: '${x['branchCode']} — ${x['holidayDate']}',
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(
        '/api/time/holiday-calendars/exceptions/${x['branchHolidayExceptionId']}',
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
    final caption = actions?['caption']?.toString() ?? 'ข้อยกเว้นวันหยุดสาขา';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.branchHolidayExceptions,
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
                    menuCode: TimeMenuCodes.branchHolidayExceptions,
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
                                    '${x['branchCode']} — ${x['holidayDate']}',
                                  ),
                                  subtitle: Text(
                                    '${x['isHoliday'] == true ? 'กำหนดเป็นวันหยุด' : 'ยกเลิกวันหยุด'}${x['holidayName'] == null ? '' : ' : ${x['holidayName']}'}\n${x['reason'] ?? ''}',
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

class _ExceptionDialog extends StatefulWidget {
  const _ExceptionDialog({required this.branches, this.value});
  final List<Map<String, dynamic>> branches;
  final Map<String, dynamic>? value;
  @override
  State<_ExceptionDialog> createState() => _ExceptionDialogState();
}

class _ExceptionDialogState extends State<_ExceptionDialog> {
  int? branch;
  late DateTime date;
  late bool isHoliday;
  late bool active;
  late TextEditingController name;
  late TextEditingController reason;
  @override
  void initState() {
    super.initState();
    branch = (widget.value?['branchId'] as num?)?.toInt();
    date =
        DateTime.tryParse(widget.value?['holidayDate']?.toString() ?? '') ??
        DateTime.now();
    isHoliday = widget.value?['isHoliday'] != false;
    active = widget.value?['isActive'] != false;
    name = TextEditingController(
      text: widget.value?['holidayName']?.toString() ?? '',
    );
    reason = TextEditingController(
      text: widget.value?['reason']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    reason.dispose();
    super.dispose();
  }

  String d() =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.event_busy_outlined),
        SizedBox(width: 8),
        Text('ข้อยกเว้นวันหยุดสาขา'),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('วันที่'),
              subtitle: Text(d()),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final x = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (x != null) setState(() => date = x);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isHoliday ? 'กำหนดเป็นวันหยุด' : 'ยกเลิกวันหยุด'),
              value: isHoliday,
              onChanged: (v) => setState(() => isHoliday = v),
            ),
            if (isHoliday)
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อวันหยุด *'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 500,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: const InputDecoration(labelText: 'เหตุผล *'),
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
              reason.text.trim().isEmpty ||
              (isHoliday && name.text.trim().isEmpty))
            return;
          Navigator.pop(context, {
            'branchId': branch,
            'holidayDate': d(),
            'isHoliday': isHoliday,
            'holidayName': isHoliday ? name.text.trim() : null,
            'reason': reason.text.trim(),
            'isActive': active,
            'rowVersion': widget.value?['rowVersion'],
          });
        },
        child: const Text('บันทึก'),
      ),
    ],
  );
}
