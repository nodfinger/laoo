import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'holiday_calendar_repository.dart';

class HolidayCalendarPage extends StatefulWidget {
  const HolidayCalendarPage({super.key});
  @override
  State<HolidayCalendarPage> createState() => _HolidayCalendarPageState();
}

class _HolidayCalendarPageState extends State<HolidayCalendarPage> {
  final search = TextEditingController();
  late final JsonApiClient api;
  late final HolidayCalendarRepository repo;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> items = const [];
  int page = 1;
  int total = 0;
  bool? active = true;
  bool loading = true;
  String? message;
  bool messageError = false;

  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = HolidayCalendarRepository(api);
    _initialize();
  }

  @override
  void dispose() {
    search.dispose();
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final value = await repo.actions();
      if (value['view'] != true)
        throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
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
        search: search.text,
        active: active,
        page: targetPage,
      );
      if (!mounted) return;
      setState(() {
        page = (value['page'] as num?)?.toInt() ?? targetPage;
        total = (value['total'] as num?)?.toInt() ?? 0;
        items = (value['items'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (error) {
      showMessage(timeErrorText(error), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String value, bool error) {
    if (mounted)
      setState(() {
        message = value;
        messageError = error;
      });
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CalendarDialog(value: row),
    );
    if (result == null) return;
    try {
      await repo.save(result);
      await load(targetPage: page);
      showMessage('บันทึกข้อมูลสำเร็จ', false);
    } catch (error) {
      showMessage(timeErrorText(error), true);
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel: '${row['calendarCode']} — ${row['calendarName']}',
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(
        (row['holidayCalendarId'] as num).toInt(),
        row['rowVersion'].toString(),
      );
      await load(targetPage: page);
      showMessage('ลบข้อมูลสำเร็จ', false);
    } catch (error) {
      showMessage(timeErrorText(error), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption']?.toString() ?? 'ปฏิทินวันหยุดบริษัท';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.holidayCalendars,
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
                    menuCode: TimeMenuCodes.holidayCalendars,
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
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: 300,
                            child: TextField(
                              controller: search,
                              onSubmitted: (_) => load(),
                              decoration: const InputDecoration(
                                labelText: 'ค้นหา',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<bool?>(
                              value: active,
                              decoration: const InputDecoration(
                                labelText: 'สถานะ',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('ใช้งาน'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('ไม่ใช้งาน'),
                                ),
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('ทั้งหมด'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => active = value),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: load,
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              search.clear();
                              setState(() => active = true);
                              load();
                            },
                            child: const Text('ล้าง Filter'),
                          ),
                        ],
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
                              itemBuilder: (_, index) {
                                final row = items[index];
                                return ListTile(
                                  title: Text(
                                    '${row['calendarCode']} — ${row['calendarName']}',
                                  ),
                                  subtitle: Text(
                                    row['descriptionText']?.toString() ??
                                        'ไม่มีรายละเอียด',
                                  ),
                                  trailing: Wrap(
                                    children: [
                                      if (actions?['edit'] == true)
                                        IconButton(
                                          tooltip: 'แก้ไข',
                                          onPressed: () => edit(row),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      if (actions?['delete'] == true)
                                        IconButton(
                                          tooltip: 'ลบ',
                                          onPressed: () => remove(row),
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

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({this.value});
  final Map<String, dynamic>? value;
  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late final TextEditingController code;
  late final TextEditingController name;
  late final TextEditingController description;
  late bool active;
  @override
  void initState() {
    super.initState();
    code = TextEditingController(
      text: widget.value?['calendarCode']?.toString() ?? '',
    );
    name = TextEditingController(
      text: widget.value?['calendarName']?.toString() ?? '',
    );
    description = TextEditingController(
      text: widget.value?['descriptionText']?.toString() ?? '',
    );
    active = widget.value?['isActive'] != false;
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.calendar_month_outlined),
        SizedBox(width: 8),
        Text('ปฏิทินวันหยุดบริษัท'),
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
              onChanged: (value) => setState(() => active = value),
            ),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'รหัสปฏิทิน *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'ชื่อปฏิทิน *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLength: 500,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: const InputDecoration(labelText: 'รายละเอียด'),
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
          if (code.text.trim().isEmpty || name.text.trim().isEmpty) return;
          Navigator.pop(context, {
            'holidayCalendarId': widget.value?['holidayCalendarId'],
            'calendarCode': code.text.trim(),
            'calendarName': name.text.trim(),
            'descriptionText': description.text.trim(),
            'isActive': active,
            'rowVersion': widget.value?['rowVersion'],
          });
        },
        child: const Text('บันทึก'),
      ),
    ],
  );
}
