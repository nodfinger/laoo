import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';

class HolidayDatePage extends StatefulWidget {
  const HolidayDatePage({super.key});
  @override
  State<HolidayDatePage> createState() => _HolidayDatePageState();
}

class _HolidayDatePageState extends State<HolidayDatePage> {
  late final JsonApiClient api;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> calendars = [];
  List<Map<String, dynamic>> items = [];
  int? calendarId;
  int page = 1;
  bool loading = true;
  String? message;
  bool messageError = false;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    _initialize();
  }

  @override
  void dispose() {
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final a = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars/dates/actions') as Map,
      );
      final c = Map<String, dynamic>.from(
        await api.get('/api/time/holiday-calendars') as Map,
      );
      if (a['view'] != true) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      calendars = (c['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['isActive'] == true)
          .toList();
      calendarId = calendars.isEmpty
          ? null
          : (calendars.first['holidayCalendarId'] as num).toInt();
      if (mounted) setState(() => actions = a);
      await load();
    } catch (e) {
      showMessage(timeErrorText(e), true);
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> load({int targetPage = 1}) async {
    if (calendarId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() => loading = true);
    try {
      final x = Map<String, dynamic>.from(
        await api.get(
              '/api/time/holiday-calendars/dates',
              query: {
                'holidayCalendarId': '$calendarId',
                'page': '$targetPage',
                'pageSize': '30',
              },
            )
            as Map,
      );
      if (mounted)
        setState(() {
          page = (x['page'] as num?)?.toInt() ?? targetPage;
          items = (x['items'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
    } catch (e) {
      showMessage(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String x, bool error) {
    if (mounted)
      setState(() {
        message = x;
        messageError = error;
      });
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    if (calendarId == null) return;
    final x = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _HolidayDateDialog(calendarId: calendarId!, value: row),
    );
    if (x == null) return;
    try {
      if (row == null) {
        await api.post('/api/time/holiday-calendars/dates', body: x);
      } else {
        await api.put(
          '/api/time/holiday-calendars/dates/${row['holidayDateId']}',
          body: x,
        );
      }
      await load(targetPage: page);
      showMessage('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      showMessage(timeErrorText(e), true);
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel: '${row['holidayDate']} — ${row['holidayName']}',
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(
        '/api/time/holiday-calendars/dates/${row['holidayDateId']}',
        query: {'rowVersion': row['rowVersion'].toString()},
      );
      await load(targetPage: page);
      showMessage('ลบข้อมูลสำเร็จ', false);
    } catch (e) {
      showMessage(timeErrorText(e), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption']?.toString() ?? 'วันหยุดในปฏิทิน';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.holidayDates,
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
                    menuCode: TimeMenuCodes.holidayDates,
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
                        width: 420,
                        child: DropdownButtonFormField<int>(
                          value: calendarId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'ปฏิทินวันหยุด',
                          ),
                          items: calendars
                              .map(
                                (x) => DropdownMenuItem(
                                  value: (x['holidayCalendarId'] as num)
                                      .toInt(),
                                  child: Text(
                                    '${x['calendarCode']} — ${x['calendarName']}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => calendarId = v);
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
                                    '${x['holidayDate']} — ${x['holidayName']}',
                                  ),
                                  subtitle: Text(
                                    x['isActive'] == true
                                        ? 'ใช้งาน'
                                        : 'ไม่ใช้งาน',
                                  ),
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

class _HolidayDateDialog extends StatefulWidget {
  const _HolidayDateDialog({required this.calendarId, this.value});
  final int calendarId;
  final Map<String, dynamic>? value;
  @override
  State<_HolidayDateDialog> createState() => _HolidayDateDialogState();
}

class _HolidayDateDialogState extends State<_HolidayDateDialog> {
  late DateTime date;
  late TextEditingController name;
  late bool active;
  @override
  void initState() {
    super.initState();
    date =
        DateTime.tryParse(widget.value?['holidayDate']?.toString() ?? '') ??
        DateTime.now();
    name = TextEditingController(
      text: widget.value?['holidayName']?.toString() ?? '',
    );
    active = widget.value?['isActive'] != false;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.event_outlined),
        SizedBox(width: 8),
        Text('วันหยุดในปฏิทิน'),
      ],
    ),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('สถานะ'),
            value: active,
            onChanged: (v) => setState(() => active = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('วันที่'),
            subtitle: Text(
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            ),
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
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'ชื่อวันหยุด *'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty) return;
          Navigator.pop(context, {
            'holidayCalendarId': widget.calendarId,
            'holidayDate':
                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            'holidayName': name.text.trim(),
            'isActive': active,
            'rowVersion': widget.value?['rowVersion'],
          });
        },
        child: const Text('บันทึก'),
      ),
    ],
  );
}
