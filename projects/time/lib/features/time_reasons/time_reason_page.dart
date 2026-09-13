import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'time_reason_repository.dart';

class TimeReasonPage extends StatefulWidget {
  const TimeReasonPage({
    required this.menuCode,
    required this.apiPath,
    super.key,
  });

  final String menuCode;
  final String apiPath;

  @override
  State<TimeReasonPage> createState() => _TimeReasonPageState();
}

class _TimeReasonPageState extends State<TimeReasonPage> {
  final search = TextEditingController();
  late final JsonApiClient api;
  late final TimeReasonRepository repo;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> items = [];
  int total = 0;
  int page = 1;
  bool? active = true;
  bool cards = false;
  bool loading = true;
  String? message;
  bool messageError = false;

  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = TimeReasonRepository(api, widget.apiPath);
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
        search: search.text,
        active: active,
        page: targetPage,
        pageSize: timePageSize,
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

  void showMessage(String value, bool error) => setState(() {
    message = value;
    messageError = error;
  });

  Future<void> edit([Map<String, dynamic>? row]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReasonDialog(
        caption: actions?['caption'] as String? ?? '',
        icon: widget.menuCode == TimeMenuCodes.onBehalfReasons
            ? Icons.person_add_alt_outlined
            : Icons.rule_outlined,
        value: row,
      ),
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
      builder: (context) => TimeDeleteDialog(
        itemLabel: '${row['reasonCode']} — ${row['reasonName']}',
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(row['id'] as int, row['rowVersion'] as String);
      await load(targetPage: page);
      showMessage('ลบข้อมูลสำเร็จ', false);
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
          title: Text('${row['reasonCode']} — ${row['reasonName']}'),
          subtitle: Text(
            '${row['requireRemark'] == true ? 'ต้องระบุหมายเหตุ' : 'ไม่บังคับหมายเหตุ'} · '
            '${row['requireEvidence'] == true ? 'ต้องแนบหลักฐาน' : 'ไม่บังคับหลักฐาน'}',
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
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
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
                  if (actions?['create'] == true)
                    FilledButton.icon(
                      onPressed: () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
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
                            DataColumn(label: Text('จัดการ')),
                            DataColumn(label: Text('รหัส')),
                            DataColumn(label: Text('ชื่อเหตุผล')),
                            DataColumn(label: Text('หมายเหตุ')),
                            DataColumn(label: Text('หลักฐาน')),
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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (actions?['edit'] == true)
                                            IconButton(
                                              onPressed: () => edit(row),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          if (actions?['delete'] == true)
                                            IconButton(
                                              onPressed: () => remove(row),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text('${row['reasonCode']}')),
                                    DataCell(Text('${row['reasonName']}')),
                                    DataCell(
                                      Icon(
                                        row['requireRemark'] == true
                                            ? Icons.check
                                            : Icons.remove,
                                      ),
                                    ),
                                    DataCell(
                                      Icon(
                                        row['requireEvidence'] == true
                                            ? Icons.check
                                            : Icons.remove,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        row['isActive'] == true
                                            ? 'ใช้งาน'
                                            : 'ไม่ใช้งาน',
                                      ),
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

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.caption, required this.icon, this.value});
  final String caption;
  final IconData icon;
  final Map<String, dynamic>? value;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController code;
  late final TextEditingController name;
  late bool requireRemark;
  late bool requireEvidence;
  late bool active;

  @override
  void initState() {
    super.initState();
    code = TextEditingController(text: widget.value?['reasonCode'] as String?);
    name = TextEditingController(text: widget.value?['reasonName'] as String?);
    requireRemark = widget.value?['requireRemark'] as bool? ?? false;
    requireEvidence = widget.value?['requireEvidence'] as bool? ?? false;
    active = widget.value?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TimeActionDialog(
    icon: widget.icon,
    title: '${widget.caption} > ${widget.value == null ? 'เพิ่ม' : 'แก้ไข'}',
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
                onChanged: (value) => setState(() => active = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: code,
            decoration: const InputDecoration(labelText: 'รหัส *'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'ชื่อเหตุผล *'),
            validator: requiredText,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('บังคับระบุหมายเหตุ'),
            value: requireRemark,
            onChanged: (value) =>
                setState(() => requireRemark = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('บังคับแนบหลักฐาน'),
            value: requireEvidence,
            onChanged: (value) =>
                setState(() => requireEvidence = value ?? false),
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
            'id': widget.value?['id'],
            'reasonCode': code.text.trim(),
            'reasonName': name.text.trim(),
            'requireRemark': requireRemark,
            'requireEvidence': requireEvidence,
            'isActive': active,
            'rowVersion': widget.value?['rowVersion'],
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;
