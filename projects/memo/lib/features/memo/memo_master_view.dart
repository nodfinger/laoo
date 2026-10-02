// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'memo_feature_host.dart';

class MemoMasterView extends StatelessWidget {
  const MemoMasterView({
    super.key,
    required this.api,
    required this.menuCode,
    required this.items,
    required this.options,
    required this.actions,
    required this.cards,
    required this.onChanged,
  });
  final JsonApiClient api;
  final String menuCode;
  final List<dynamic> items;
  final Map<String, dynamic> options, actions;
  final bool cards;
  final Future<void> Function() onChanged;
  String get endpoint => switch (menuCode) {
    '50002' => 'types',
    '50003' => 'routes',
    _ => 'templates',
  };
  String get noun => switch (menuCode) {
    '50002' => 'ประเภท Memo',
    '50003' => 'สายอนุมัติ',
    _ => 'Template Memo',
  };
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (actions['create'] == true)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: Text('เพิ่ม$noun'),
          ),
        ),
      if (actions['create'] == true) const SizedBox(height: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (items.isEmpty) {
              return LaooTableCard(
                tokens: memoTokens,
                child: const Center(child: Text('ยังไม่มีข้อมูล')),
              );
            }
            if (cards || constraints.maxWidth < memoTokens.compactBreakpoint) {
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: memoTokens.itemSpacing),
                itemBuilder: (_, index) {
                  final value = _map(items[index]);
                  return LaooSurfaceCard(
                    tokens: memoTokens,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID ${index + 1} · ${value['code'] ?? ''}',
                                style: memoTokens.sectionStyle,
                              ),
                              Text('${value['name'] ?? ''}'),
                              Text(
                                value['active'] == false
                                    ? 'ปิดใช้งาน'
                                    : 'ใช้งาน',
                              ),
                            ],
                          ),
                        ),
                        _rowActions(context, value),
                      ],
                    ),
                  );
                },
              );
            }
            return LaooTableCard(
              tokens: memoTokens,
              child: LaooWorkspaceDataTable(
                tokens: memoTokens,
                columns: const [
                  LaooWorkspaceTableColumns.id,
                  DataColumn(
                    label: Center(child: Text('Action')),
                    columnWidth: FixedColumnWidth(100),
                  ),
                  DataColumn(label: Text('รหัส')),
                  DataColumn(label: Text('ชื่อ')),
                  DataColumn(label: Text('สถานะ')),
                ],
                rows: List<DataRow>.generate(items.length, (index) {
                  final value = _map(items[index]);
                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Center(child: _rowActions(context, value))),
                      DataCell(Text('${value['code'] ?? ''}')),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(
                            '${value['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(value['active'] == false ? 'ปิดใช้งาน' : 'ใช้งาน'),
                      ),
                    ],
                  );
                }),
              ),
            );
          },
        ),
      ),
      SizedBox(height: memoTokens.sectionSpacing),
      LaooPaginationCard(
        tokens: memoTokens,
        page: 1,
        pageCount: 1,
        pageSize: items.isEmpty ? 10 : items.length,
        total: items.length,
        onPrevious: null,
        onNext: null,
      ),
    ],
  );

  Widget _rowActions(BuildContext context, Map<String, dynamic> value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: memoTokens.primaryColor,
          onPressed: () => _edit(context, value),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _delete(context, value),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
  Future<void> _edit(BuildContext context, Map<String, dynamic>? value) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MasterDialog(
        api: api,
        endpoint: endpoint,
        noun: noun,
        menuCode: menuCode,
        value: value,
        options: options,
      ),
    );
    if (saved == true) await onChanged();
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
        content: Text(
          '${x['code']} — ${x['name']}\nลบแล้วไม่สามารถเรียกคืนได้',
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
      await api.delete('/api/company/memo/$endpoint/${x['id']}');
      if (context.mounted) memoMessage(context, 'ลบข้อมูลแล้ว');
      await onChanged();
    } catch (e) {
      if (context.mounted) memoMessage(context, 'ลบไม่สำเร็จ: $e', error: true);
    }
  }
}

class _MasterDialog extends StatefulWidget {
  const _MasterDialog({
    required this.api,
    required this.endpoint,
    required this.noun,
    required this.menuCode,
    required this.value,
    required this.options,
  });
  final JsonApiClient api;
  final String endpoint, noun, menuCode;
  final Map<String, dynamic>? value;
  final Map<String, dynamic> options;
  @override
  State<_MasterDialog> createState() => _DialogState();
}

class _DialogState extends State<_MasterDialog> {
  late final code = TextEditingController(
    text: '${widget.value?['code'] ?? ''}',
  );
  late final name = TextEditingController(
    text: '${widget.value?['name'] ?? ''}',
  );
  late final extra = TextEditingController(
    text: widget.menuCode == '50002'
        ? '${widget.value?['prefix'] ?? 'MEMO'}'
        : '${widget.value?['subject'] ?? ''}',
  );
  late final body = TextEditingController(
    text: '${widget.value?['body'] ?? ''}',
  );
  bool active = true, saving = false;
  String secret = 'INTERNAL';
  final assignees = <int?>[];
  @override
  void initState() {
    super.initState();
    active = widget.value?['active'] != false;
    secret = '${widget.value?['confidentiality'] ?? 'INTERNAL'}';
    final steps = widget.value?['steps'];
    if (steps is List) {
      assignees.addAll(
        steps.map((step) => int.tryParse('${_map(step)['userId']}')),
      );
    }
    if (widget.menuCode == '50003' && assignees.isEmpty) assignees.add(null);
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    extra.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (code.text.trim().isEmpty ||
        name.text.trim().isEmpty ||
        (widget.menuCode == '50003' &&
            (assignees.isEmpty || assignees.any((value) => value == null)))) {
      memoMessage(context, 'กรอกข้อมูลบังคับให้ครบ', error: true);
      return;
    }
    setState(() => saving = true);
    final payload = widget.menuCode == '50002'
        ? {
            'code': code.text,
            'name': name.text,
            'prefix': extra.text,
            'confidentiality': secret,
            'active': active,
          }
        : widget.menuCode == '50003'
        ? {
            'code': code.text,
            'name': name.text,
            'active': active,
            'steps': [
              for (var index = 0; index < assignees.length; index++)
                {
                  'userId': assignees[index],
                  'name': 'ผู้อนุมัติขั้นที่ ${index + 1}',
                },
            ],
          }
        : {
            'code': code.text,
            'name': name.text,
            'subject': extra.text,
            'body': body.text,
            'delta': '[{"insert":"${body.text.replaceAll('"', '\\"')}\\n"}]',
            'active': active,
          };
    try {
      final id = widget.value?['id'];
      if (id == null)
        await widget.api.post(
          '/api/company/memo/${widget.endpoint}',
          body: payload,
        );
      else
        await widget.api.put(
          '/api/company/memo/${widget.endpoint}/$id',
          body: payload,
        );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) memoMessage(context, 'บันทึกไม่สำเร็จ: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _list(widget.options['users']);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.noun} > ${widget.value == null ? 'เพิ่ม' : 'แก้ไข'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('สถานะ'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                    _field(code, 'รหัส *'),
                    const SizedBox(height: 16),
                    _field(name, 'ชื่อ *'),
                    const SizedBox(height: 16),
                    if (widget.menuCode == '50002') ...[
                      _field(extra, 'รูปแบบเลขที่ *'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: secret,
                        decoration: const InputDecoration(
                          labelText: 'ชั้นความลับเริ่มต้น *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'NORMAL',
                            child: Text('ปกติ'),
                          ),
                          DropdownMenuItem(
                            value: 'INTERNAL',
                            child: Text('ภายใน'),
                          ),
                          DropdownMenuItem(value: 'SECRET', child: Text('ลับ')),
                        ],
                        onChanged: (v) => setState(() => secret = v!),
                      ),
                    ],
                    if (widget.menuCode == '50003')
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < assignees.length;
                            index++
                          ) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    key: ValueKey(
                                      'approver-$index-${assignees[index]}',
                                    ),
                                    initialValue: assignees[index],
                                    decoration: InputDecoration(
                                      labelText:
                                          'ผู้อนุมัติขั้นที่ ${index + 1} *',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: users.map((raw) {
                                      final user = _map(raw);
                                      return DropdownMenuItem(
                                        value: int.tryParse('${user['id']}'),
                                        child: Text(
                                          '${user['name']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(
                                      () => assignees[index] = value,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'ลบขั้น',
                                  onPressed: assignees.length == 1
                                      ? null
                                      : () => setState(
                                          () => assignees.removeAt(index),
                                        ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => assignees.add(null)),
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มขั้นอนุมัติ'),
                            ),
                          ),
                        ],
                      ),
                    if (widget.menuCode == '50004') ...[
                      _field(extra, 'เรื่องเริ่มต้น'),
                      const SizedBox(height: 16),
                      _field(body, 'เนื้อหาเริ่มต้น', maxLines: 8),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
    ? v.map((k, v) => MapEntry('$k', v))
    : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : <dynamic>[];
