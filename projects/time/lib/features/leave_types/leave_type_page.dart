import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'leave_type_repository.dart';

class LeaveTypePage extends StatefulWidget {
  const LeaveTypePage({super.key});
  @override
  State<LeaveTypePage> createState() => _LeaveTypePageState();
}

class _LeaveTypePageState extends State<LeaveTypePage> {
  final search = TextEditingController();
  late final dynamic api;
  late final LeaveTypeRepository repo;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> items = [];
  int total = 0, page = 1;
  bool? active = true;
  bool loading = true, error = false;
  String? message;

  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = LeaveTypeRepository(api);
    initialize();
  }

  @override
  void dispose() {
    search.dispose();
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      actions = await repo.actions();
      await load();
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Future<void> load({int target = 1}) async {
    setState(() => loading = true);
    try {
      final value = await repo.list(
        search: search.text,
        active: active,
        page: target,
        pageSize: timePageSize,
      );
      if (!mounted) return;
      setState(() {
        page = (value['page'] as num?)?.toInt() ?? target;
        total = (value['total'] as num?)?.toInt() ?? 0;
        items = (value['items'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
      });
    } catch (e) {
      notice(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void notice(String value, bool isError) => setState(() {
    message = value;
    error = isError;
  });
  Future<void> edit([Map<String, dynamic>? item]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LeaveTypeDialog(
        caption: actions?['caption'] as String? ?? '',
        item: item,
      ),
    );
    if (result == null) return;
    try {
      await repo.save(result);
      await load(target: page);
      notice('บันทึกข้อมูลสำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel: '${item['leaveTypeCode']} — ${item['leaveTypeName']}',
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(item['id'] as int, item['rowVersion'] as String);
      await load(target: page);
      notice('ลบข้อมูลสำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption'] as String? ?? '';
    final pages = total == 0 ? 1 : (total / timePageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.leaveTypes,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: api,
              menuCode: TimeMenuCodes.leaveTypes,
              caption: caption,
              trailing: actions?['create'] == true
                  ? FilledButton.icon(
                      onPressed: () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    )
                  : null,
            ),
            filter: Wrap(
              spacing: timeUiTokens.itemSpacing,
              runSpacing: timeUiTokens.itemSpacing,
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
                    initialValue: active,
                    decoration: const InputDecoration(labelText: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('ใช้งาน')),
                      DropdownMenuItem(value: false, child: Text('ไม่ใช้งาน')),
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    ],
                    onChanged: (value) => setState(() => active = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : () => load(),
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
            table: loading
                ? const Center(child: CircularProgressIndicator())
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
                          columns: const [
                            LaooWorkspaceTableColumns.id,
                            DataColumn(label: Text('จัดการ')),
                            DataColumn(label: Text('รหัส')),
                            DataColumn(label: Text('ประเภทการลา')),
                            DataColumn(label: Text('หน่วย')),
                            DataColumn(label: Text('ได้รับค่าจ้าง')),
                            DataColumn(label: Text('สถานะ')),
                          ],
                          rows: items.asMap().entries.map((entry) {
                            final x = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${(page - 1) * timePageSize + entry.key + 1}',
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (actions?['edit'] == true)
                                        IconButton(
                                          onPressed: () => edit(x),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      if (actions?['delete'] == true)
                                        IconButton(
                                          onPressed: () => remove(x),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${x['leaveTypeCode']}')),
                                DataCell(Text('${x['leaveTypeName']}')),
                                DataCell(
                                  Text(x['unitCode'] == 'DAY' ? 'วัน' : 'นาที'),
                                ),
                                DataCell(
                                  Text(x['isPaid'] == true ? 'ใช่' : 'ไม่ใช่'),
                                ),
                                DataCell(
                                  Text(
                                    x['isActive'] == true
                                        ? 'ใช้งาน'
                                        : 'ไม่ใช้งาน',
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
            pagination: LaooPaginationCard(
              tokens: timeUiTokens.workspace,
              page: page,
              pageCount: pages,
              pageSize: timePageSize,
              total: total,
              onPrevious: page > 1 ? () => load(target: page - 1) : null,
              onNext: page < pages ? () => load(target: page + 1) : null,
            ),
          ),
          if (message != null)
            Positioned(
              right: 16,
              top: 16,
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

class _LeaveTypeDialog extends StatefulWidget {
  const _LeaveTypeDialog({required this.caption, this.item});
  final String caption;
  final Map<String, dynamic>? item;
  @override
  State<_LeaveTypeDialog> createState() => _LeaveTypeDialogState();
}

class _LeaveTypeDialogState extends State<_LeaveTypeDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController code, name;
  late String unit;
  late bool paid, remark, evidence, active;
  @override
  void initState() {
    super.initState();
    code = TextEditingController(
      text: widget.item?['leaveTypeCode'] as String?,
    );
    name = TextEditingController(
      text: widget.item?['leaveTypeName'] as String?,
    );
    unit = widget.item?['unitCode'] as String? ?? 'DAY';
    paid = widget.item?['isPaid'] as bool? ?? true;
    remark = widget.item?['requireRemark'] as bool? ?? false;
    evidence = widget.item?['requireEvidence'] as bool? ?? false;
    active = widget.item?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TimeActionDialog(
    icon: Icons.event_note_outlined,
    title: '${widget.caption} > ${widget.item == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('สถานะ'),
              const SizedBox(width: 8),
              Switch(
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: code,
            decoration: const InputDecoration(labelText: 'รหัสประเภทลา *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'ชื่อประเภทลา *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: unit,
            decoration: const InputDecoration(labelText: 'หน่วยสิทธิ์ลา'),
            items: const [
              DropdownMenuItem(value: 'DAY', child: Text('วัน')),
              DropdownMenuItem(value: 'MINUTE', child: Text('นาที')),
            ],
            onChanged: (v) => setState(() => unit = v ?? 'DAY'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ได้รับค่าจ้าง'),
            value: paid,
            onChanged: (v) => setState(() => paid = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('บังคับระบุหมายเหตุ'),
            value: remark,
            onChanged: (v) => setState(() => remark = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('บังคับแนบหลักฐาน'),
            value: evidence,
            onChanged: (v) => setState(() => evidence = v ?? false),
          ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (key.currentState?.validate() != true) return;
          Navigator.pop(context, {
            'id': widget.item?['id'],
            'leaveTypeCode': code.text.trim(),
            'leaveTypeName': name.text.trim(),
            'unitCode': unit,
            'isPaid': paid,
            'requireRemark': remark,
            'requireEvidence': evidence,
            'isActive': active,
            'rowVersion': widget.item?['rowVersion'],
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}
