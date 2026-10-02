// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'memo_feature_host.dart';

class MemoDocumentsView extends StatefulWidget {
  const MemoDocumentsView({
    super.key,
    required this.api,
    required this.value,
    required this.options,
    required this.actions,
    required this.cards,
    required this.onChanged,
  });
  final JsonApiClient api;
  final dynamic value;
  final Map<String, dynamic> options, actions;
  final bool cards;
  final Future<void> Function() onChanged;
  @override
  State<MemoDocumentsView> createState() => _State();
}

class _State extends State<MemoDocumentsView> {
  bool editor = false;
  Map<String, dynamic>? current;
  @override
  void initState() {
    super.initState();
    editor = widget.value is Map && widget.value['editor'] == true;
  }

  Future<void> edit(dynamic raw) async {
    try {
      final x = _map(raw);
      final value = await widget.api.get(
        '/api/company/memo/documents/${x['id']}',
      );
      if (mounted)
        setState(() {
          current = _map(value);
          editor = true;
        });
    } catch (e) {
      if (mounted) memoMessage(context, 'เปิด Memo ไม่สำเร็จ: $e', error: true);
    }
  }

  Future<void> createRevision(Map<String, dynamic> value) async {
    try {
      await widget.api.post(
        '/api/company/memo/documents/${value['id']}/revisions',
      );
      if (mounted) memoMessage(context, 'สร้าง Version ใหม่แล้ว');
      await edit(value);
    } catch (e) {
      if (mounted)
        memoMessage(context, 'สร้าง Version ไม่สำเร็จ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => editor
      ? _MemoEditor(
          api: widget.api,
          options: widget.options,
          actions: widget.actions,
          value: current,
          onClose: () async {
            setState(() {
              editor = false;
              current = null;
            });
            await widget.onChanged();
          },
        )
      : _list();
  Widget _list() {
    final root = _map(widget.value);
    final items = _listOf(root['items']);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (items.isEmpty) {
                return LaooTableCard(
                  tokens: memoTokens,
                  child: const Center(child: Text('ยังไม่มี Memo')),
                );
              }
              if (widget.cards ||
                  constraints.maxWidth < memoTokens.compactBreakpoint) {
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: memoTokens.itemSpacing),
                  itemBuilder: (_, index) {
                    final value = _map(items[index]);
                    return LaooSurfaceCard(
                      tokens: memoTokens,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID ${index + 1} · ${value['memoNo'] ?? value['temporaryNo'] ?? ''}',
                                  style: memoTokens.sectionStyle,
                                ),
                                Text('${value['subject'] ?? ''}'),
                                Text('เรียน ${value['recipient'] ?? '-'}'),
                                _status('${value['status']}'),
                              ],
                            ),
                          ),
                          _actions(value),
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
                    DataColumn(label: Text('เลขที่')),
                    DataColumn(label: Text('เรื่อง')),
                    DataColumn(label: Text('เรียน')),
                    DataColumn(label: Text('สถานะ')),
                  ],
                  rows: List<DataRow>.generate(items.length, (index) {
                    final value = _map(items[index]);
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Center(child: _actions(value))),
                        DataCell(
                          Text(
                            '${value['memoNo'] ?? value['temporaryNo'] ?? ''}',
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 360,
                            child: Text(
                              '${value['subject'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text('${value['recipient'] ?? ''}')),
                        DataCell(_status('${value['status']}')),
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
  }

  Widget _actions(Map<String, dynamic> value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'ดู',
        color: memoTokens.primaryColor,
        onPressed: () => edit(value),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (widget.actions['edit'] == true &&
          ['DRAFT', 'RETURNED', 'WITHDRAWN'].contains(value['status']))
        IconButton(
          tooltip: 'แก้ไข',
          color: memoTokens.primaryColor,
          onPressed: () => edit(value),
          icon: const Icon(Icons.edit_outlined),
        ),
    ],
  );

  Widget _status(String s) => Chip(
    label: Text(_statusName(s)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    side: BorderSide.none,
  );
}

class _MemoEditor extends StatefulWidget {
  const _MemoEditor({
    required this.api,
    required this.options,
    required this.actions,
    required this.value,
    required this.onClose,
  });
  final JsonApiClient api;
  final Map<String, dynamic> options, actions;
  final Map<String, dynamic>? value;
  final Future<void> Function() onClose;
  @override
  State<_MemoEditor> createState() => _EditorState();
}

class _EditorState extends State<_MemoEditor> {
  late final subject = TextEditingController(
    text: '${widget.value?['subject'] ?? ''}',
  );
  late final recipient = TextEditingController(
    text: '${widget.value?['recipient'] ?? ''}',
  );
  late QuillController quill;
  int? typeId, routeId, memoId;
  final recipientRows = <Map<String, dynamic>>[];
  String secret = 'INTERNAL';
  bool saving = false;
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    typeId = _int(widget.value?['typeId']);
    memoId = _int(widget.value?['id']);
    final initialRecipients = widget.value?['recipients'];
    if (initialRecipients is List) {
      recipientRows.addAll(initialRecipients.map(_map));
    }
    secret = '${widget.value?['confidentiality'] ?? 'INTERNAL'}';
    date =
        DateTime.tryParse('${widget.value?['memoDate'] ?? ''}') ??
        DateTime.now();
    quill = QuillController(
      document: _document(widget.value?['delta'], widget.value?['body']),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Document _document(dynamic delta, dynamic body) {
    try {
      final json = jsonDecode('$delta');
      if (json is List) return Document.fromJson(json);
    } catch (_) {}
    return Document()..insert(0, '${body ?? ''}');
  }

  @override
  void dispose() {
    subject.dispose();
    recipient.dispose();
    quill.dispose();
    super.dispose();
  }

  Future<int?> save() async {
    if (typeId == null ||
        subject.text.trim().isEmpty ||
        recipient.text.trim().isEmpty ||
        recipientRows.every((row) => row['role'] != 'TO') ||
        quill.document.toPlainText().trim().isEmpty) {
      memoMessage(
        context,
        'กรอกประเภท เรื่อง เรียน ผู้รับหลัก และเนื้อหาให้ครบ',
        error: true,
      );
      return null;
    }
    setState(() => saving = true);
    final recipients = recipientRows
        .map(
          (row) => {
            'role': row['role'],
            'subjectType': row['subjectType'],
            'subjectId': row['subjectId'],
          },
        )
        .toList();
    final payload = {
      'typeId': typeId,
      'subject': subject.text.trim(),
      'recipient': recipient.text.trim(),
      'memoDate': date.toIso8601String(),
      'confidentiality': secret,
      'delta': jsonEncode(quill.document.toDelta().toJson()),
      'body': quill.document.toPlainText(),
      'recipients': recipients,
    };
    try {
      final id = memoId;
      final result = id == null
          ? await widget.api.post('/api/company/memo/documents', body: payload)
          : await widget.api.put(
              '/api/company/memo/documents/$id',
              body: payload,
            );
      final saved = _int(_map(result)['id']) ?? id;
      memoId = saved;
      if (mounted) memoMessage(context, 'บันทึก Memo แล้ว');
      return saved;
    } catch (e) {
      if (mounted) memoMessage(context, 'บันทึกไม่สำเร็จ: $e', error: true);
      return null;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editRecipients(List<dynamic> users) async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecipientDialog(
        users: users,
        departments: _listOf(widget.options['departments']),
        roles: _listOf(widget.options['roles']),
        initial: recipientRows,
      ),
    );
    if (result != null)
      setState(() {
        recipientRows
          ..clear()
          ..addAll(result);
      });
  }

  Future<void> upload() async {
    if (memoId == null) {
      memoMessage(context, 'บันทึก Memo ก่อนแนบไฟล์', error: true);
      return;
    }
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    try {
      await memoUpload(
        '/api/company/memo/documents/$memoId/attachments',
        fileName: file.name,
        bytes: file.bytes!,
        fields: const {'kind': 'ATTACHMENT'},
      );
      if (mounted) memoMessage(context, 'แนบไฟล์แล้ว');
    } catch (e) {
      if (mounted) memoMessage(context, 'แนบไฟล์ไม่สำเร็จ: $e', error: true);
    }
  }

  Future<void> submit() async {
    final id = await save();
    if (id == null || routeId == null) {
      if (mounted && routeId == null)
        memoMessage(context, 'เลือกสายอนุมัติก่อนส่ง', error: true);
      return;
    }
    try {
      await widget.api.post(
        '/api/company/memo/documents/$id/submit',
        body: {'routeId': routeId},
      );
      if (mounted) memoMessage(context, 'ส่ง Memo เข้าสายอนุมัติแล้ว');
      await widget.onClose();
    } catch (e) {
      if (mounted) memoMessage(context, 'ส่งอนุมัติไม่สำเร็จ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _listOf(widget.options['types']),
        routes = _listOf(widget.options['routes']),
        users = _listOf(widget.options['users']);
    final editable =
        widget.value == null ||
        ['DRAFT', 'RETURNED', 'WITHDRAWN'].contains(widget.value?['status']);
    quill.readOnly = !editable;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  children: [
                    LaooSurfaceCard(
                      tokens: memoTokens,
                      child: LayoutBuilder(
                        builder: (context, c) => Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: c.maxWidth < 700 ? c.maxWidth : 340,
                              child: DropdownButtonFormField<int>(
                                initialValue: typeId,
                                decoration: const InputDecoration(
                                  labelText: 'ประเภท Memo *',
                                  border: OutlineInputBorder(),
                                ),
                                items: types.map((e) {
                                  final x = _map(e);
                                  return DropdownMenuItem(
                                    value: _int(x['id']),
                                    child: Text('${x['name']}'),
                                  );
                                }).toList(),
                                onChanged: editable
                                    ? (v) => setState(() => typeId = v)
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: c.maxWidth < 700 ? c.maxWidth : 220,
                              child: DropdownButtonFormField<String>(
                                initialValue: secret,
                                decoration: const InputDecoration(
                                  labelText: 'ชั้นความลับ *',
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
                                  DropdownMenuItem(
                                    value: 'SECRET',
                                    child: Text('ลับ'),
                                  ),
                                ],
                                onChanged: editable
                                    ? (v) => setState(() => secret = v!)
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: c.maxWidth < 700 ? c.maxWidth : 340,
                              child: TextField(
                                controller: subject,
                                enabled: editable,
                                decoration: const InputDecoration(
                                  labelText: 'เรื่อง *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: c.maxWidth < 700 ? c.maxWidth : 340,
                              child: TextField(
                                controller: recipient,
                                enabled: editable,
                                decoration: const InputDecoration(
                                  labelText: 'เรียน *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: c.maxWidth < 700 ? c.maxWidth : 340,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: editable
                                    ? () => editRecipients(users)
                                    : null,
                                icon: const Icon(Icons.group_add_outlined),
                                label: Text(
                                  recipientRows.isEmpty
                                      ? 'เลือกผู้รับและสำเนา *'
                                      : 'ผู้รับและสำเนา ${recipientRows.length} รายการ',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: c.maxWidth < 700 ? c.maxWidth : 340,
                              child: DropdownButtonFormField<int>(
                                initialValue: routeId,
                                decoration: const InputDecoration(
                                  labelText: 'สายอนุมัติ',
                                  border: OutlineInputBorder(),
                                ),
                                items: routes.map((e) {
                                  final x = _map(e);
                                  return DropdownMenuItem(
                                    value: _int(x['id']),
                                    child: Text(
                                      '${x['name']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: editable
                                    ? (v) => setState(() => routeId = v)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LaooSurfaceCard(
                      tokens: memoTokens,
                      child: Column(
                        children: [
                          if (editable)
                            QuillSimpleToolbar(
                              controller: quill,
                              config: const QuillSimpleToolbarConfig(
                                showFontFamily: false,
                                showFontSize: false,
                                showSearchButton: false,
                              ),
                            ),
                          const Divider(height: 1),
                          Container(
                            height: 520,
                            color: Colors.white,
                            padding: const EdgeInsets.all(24),
                            child: QuillEditor.basic(
                              controller: quill,
                              config: const QuillEditorConfig(
                                padding: EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        LaooSurfaceCard(
          tokens: memoTokens,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: saving ? null : widget.onClose,
                child: const Text('ยกเลิก'),
              ),
              if (editable && widget.actions['edit'] == true ||
                  widget.value == null && widget.actions['create'] == true) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              ],
              if (editable && widget.actions['upload'] == true) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: saving ? null : upload,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('แนบไฟล์'),
                ),
              ],
              if (editable && widget.actions['submit'] == true) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('ส่งอนุมัติ'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecipientDialog extends StatefulWidget {
  const _RecipientDialog({
    required this.users,
    required this.departments,
    required this.roles,
    required this.initial,
  });
  final List<dynamic> users, departments, roles;
  final List<Map<String, dynamic>> initial;
  @override
  State<_RecipientDialog> createState() => _RecipientDialogState();
}

class _RecipientDialogState extends State<_RecipientDialog> {
  late final rows = widget.initial
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  void add() => setState(
    () => rows.add({'role': 'TO', 'subjectType': 'USER', 'subjectId': null}),
  );
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ผู้รับและสำเนา',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('ยังไม่ได้เลือกผู้รับ'))
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final subjectType = '${row['subjectType'] ?? 'USER'}';
                      final choices = subjectType == 'DEPARTMENT'
                          ? widget.departments
                          : subjectType == 'ROLE'
                          ? widget.roles
                          : widget.users;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: DropdownButtonFormField<String>(
                              initialValue: '${row['role'] ?? 'TO'}',
                              decoration: const InputDecoration(
                                labelText: 'ประเภท',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'TO',
                                  child: Text('ผู้รับ'),
                                ),
                                DropdownMenuItem(
                                  value: 'CC',
                                  child: Text('สำเนา'),
                                ),
                              ],
                              onChanged: (v) => setState(() => row['role'] = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              initialValue: subjectType,
                              decoration: const InputDecoration(
                                labelText: 'ขอบเขต',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'USER',
                                  child: Text('บุคคล'),
                                ),
                                DropdownMenuItem(
                                  value: 'DEPARTMENT',
                                  child: Text('แผนก'),
                                ),
                                DropdownMenuItem(
                                  value: 'ROLE',
                                  child: Text('กลุ่ม'),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                row['subjectType'] = v;
                                row['subjectId'] = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(
                                '$index-${row['subjectType']}-${row['subjectId']}',
                              ),
                              initialValue: _int(row['subjectId']),
                              decoration: const InputDecoration(
                                labelText: 'ผู้รับ *',
                                border: OutlineInputBorder(),
                              ),
                              items: choices.map((raw) {
                                final item = _map(raw);
                                return DropdownMenuItem(
                                  value: _int(item['id']),
                                  child: Text(
                                    '${item['name']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => row['subjectId'] = v),
                            ),
                          ),
                          IconButton(
                            tooltip: 'ลบ',
                            onPressed: () =>
                                setState(() => rows.removeAt(index)),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มผู้รับ'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      rows.isNotEmpty &&
                          rows.every((e) => _int(e['subjectId']) != null)
                      ? () => Navigator.pop(context, rows)
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('ตกลง'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
    ? v.map((k, v) => MapEntry('$k', v))
    : <String, dynamic>{};
List<dynamic> _listOf(dynamic v) => v is List ? v : <dynamic>[];
int? _int(dynamic v) => v is int ? v : int.tryParse('$v');
String _statusName(String s) =>
    const {
      'DRAFT': 'ร่าง',
      'IN_APPROVAL': 'รออนุมัติ',
      'RETURNED': 'ส่งกลับ',
      'APPROVED': 'อนุมัติแล้ว',
      'DISTRIBUTED': 'แจกจ่ายแล้ว',
      'WITHDRAWN': 'ถอนแล้ว',
      'CANCELLED': 'ยกเลิก',
    }[s] ??
    s;
