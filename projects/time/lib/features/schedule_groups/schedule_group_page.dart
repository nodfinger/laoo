import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'schedule_group_models.dart';
import 'schedule_group_repository.dart';

class ScheduleGroupPage extends StatefulWidget {
  const ScheduleGroupPage({super.key});
  @override
  State<ScheduleGroupPage> createState() => _State();
}

class _State extends State<ScheduleGroupPage> {
  final search = TextEditingController();
  late final JsonApiClient api;
  late final ScheduleGroupRepository repo;
  ScheduleGroupActions? actions;
  ScheduleGroupResult data = const ScheduleGroupResult(
    total: 0,
    page: 1,
    pageSize: 30,
    items: [],
  );
  bool loading = true;
  bool? active = true;
  bool cards = false;
  String? message;
  bool error = false;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = ScheduleGroupRepository(api);
    init();
  }

  @override
  void dispose() {
    search.dispose();
    disposeTimeApiClient(api);
    super.dispose();
  }

  void notice(String x, bool e) {
    if (mounted) {
      setState(() {
        message = x;
        error = e;
      });
    }
  }

  Future<void> init() async {
    try {
      final a = await repo.actions();
      if (!a.view) throw StateError('ไม่มีสิทธิ์ดูข้อมูลหน้าจอนี้');
      setState(() => actions = a);
      await load();
    } catch (e) {
      notice(timeErrorText(e), true);
      setState(() => loading = false);
    }
  }

  Future<void> load({int page = 1}) async {
    setState(() => loading = true);
    try {
      final x = await repo.list(
        search: search.text,
        active: active,
        page: page,
        pageSize: timePageSize,
      );
      if (mounted) setState(() => data = x);
    } catch (e) {
      notice(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([ScheduleGroup? source]) async {
    final x = source == null
        ? ScheduleGroup(code: '', name: '')
        : ScheduleGroup(
            id: source.id,
            code: source.code,
            name: source.name,
            description: source.description,
            active: source.active,
            members: source.members,
            rowVersion: source.rowVersion,
          );
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(
          x.id == null ? 'เพิ่มกลุ่มตารางทำงาน' : 'แก้ไขกลุ่มตารางทำงาน',
        ),
        content: SizedBox(
          width: 560,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('สถานะ'),
                    const SizedBox(width: 8),
                    StatefulBuilder(
                      builder: (c, set) => Switch(
                        value: x.active,
                        onChanged: (v) => set(() => x.active = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: x.code,
                  decoration: const InputDecoration(labelText: 'รหัสกลุ่ม *'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'กรุณาระบุรหัสกลุ่ม' : null,
                  onChanged: (v) => x.code = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: x.name,
                  decoration: const InputDecoration(labelText: 'ชื่อกลุ่ม *'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'กรุณาระบุชื่อกลุ่ม' : null,
                  onChanged: (v) => x.name = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: x.description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'รายละเอียด'),
                  onChanged: (v) => x.description = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(c, true);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await repo.save(x);
      await load(page: data.page);
      notice('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Future<void> remove(ScheduleGroup x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 42),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text('${x.code} — ${x.name}'),
            ),
            const SizedBox(height: 12),
            const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(x);
      await load(page: data.page);
      notice('ลบข้อมูลสำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Widget _table() => LaooWorkspaceDataTable(
    tokens: timeUiTokens.workspace,
    headingRowColor: WidgetStatePropertyAll(
      timeUiTokens.primaryColor.withValues(alpha: .10),
    ),
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ'), columnWidth: FixedColumnWidth(112)),
      DataColumn(label: Text('รหัส')),
      DataColumn(label: Text('ชื่อกลุ่ม'), columnWidth: FlexColumnWidth()),
      DataColumn(label: Text('สมาชิก')),
      DataColumn(label: Text('สถานะ')),
    ],
    rows: [
      for (var index = 0; index < data.items.length; index++)
        DataRow(
          cells: [
            DataCell(Text('${(data.page - 1) * data.pageSize + index + 1}')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'แก้ไข',
                    onPressed: actions?.edit == true
                        ? () => edit(data.items[index])
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'ลบ',
                    onPressed: actions?.delete == true
                        ? () => remove(data.items[index])
                        : null,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
            DataCell(Text(data.items[index].code)),
            DataCell(Text(data.items[index].name)),
            DataCell(Text('${data.items[index].members}')),
            DataCell(Text(data.items[index].active ? 'ใช้งาน' : 'ไม่ใช้งาน')),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final caption = actions?.caption ?? 'กลุ่มตารางทำงาน';
    final pages = data.total == 0 ? 1 : (data.total / data.pageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.scheduleGroups,
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
                    menuCode: TimeMenuCodes.scheduleGroups,
                    caption: caption,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LaooListCardToggle(
                          tokens: timeUiTokens.workspace,
                          cards: cards,
                          onChanged: (value) => setState(() => cards = value),
                        ),
                        if (actions?.create == true)
                          FilledButton.icon(
                            onPressed: () => edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่ม'),
                          ),
                      ],
                    ),
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
                                labelText: 'ค้นหารหัสหรือชื่อกลุ่ม',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<bool?>(
                              initialValue: active,
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
                              onChanged: (v) => setState(() => active = v),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: loading ? null : () => load(),
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: timeUiTokens.cardSpacing),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : data.items.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : cards
                          ? ListView.separated(
                              itemCount: data.items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (c, i) {
                                final x = data.items[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${(data.page - 1) * data.pageSize + i + 1}',
                                    ),
                                  ),
                                  title: Text('${x.code} — ${x.name}'),
                                  subtitle: Text(
                                    'สมาชิกปัจจุบัน ${x.members} คน · ${x.active ? 'ใช้งาน' : 'ไม่ใช้งาน'}',
                                  ),
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'แก้ไข',
                                        onPressed: actions?.edit == true
                                            ? () => edit(x)
                                            : null,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'ลบ',
                                        onPressed: actions?.delete == true
                                            ? () => remove(x)
                                            : null,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : _table(),
                    ),
                  ),
                  SizedBox(height: timeUiTokens.cardSpacing),
                  LaooPaginationCard(
                    tokens: timeUiTokens.workspace,
                    page: data.page,
                    pageCount: pages,
                    pageSize: data.pageSize,
                    total: data.total,
                    onPrevious: data.page > 1
                        ? () => load(page: data.page - 1)
                        : null,
                    onNext: data.page < pages
                        ? () => load(page: data.page + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (message != null)
            Positioned(
              top: 12,
              right: 12,
              child: buildTimeMessage(
                message: message!,
                error: error,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}
