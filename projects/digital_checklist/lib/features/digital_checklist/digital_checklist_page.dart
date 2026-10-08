import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'digital_checklist_host.dart';

class DigitalChecklistPage extends StatefulWidget {
  const DigitalChecklistPage({required this.menuCode, super.key});
  final String menuCode;
  @override
  State<DigitalChecklistPage> createState() => _DigitalChecklistPageState();
}

class _DigitalChecklistPageState extends State<DigitalChecklistPage> {
  late final JsonApiClient api = checklistApi();
  late Future<void> loading;
  String title = 'ระบบตรวจสอบดิจิทัล';
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> actions = {};
  Map<String, dynamic> options = {};
  List<Map<String, dynamic>> notices = [];
  String search = '';
  bool cards = false;
  final Set<int> uploadingEvidence = {};
  int page = 1;
  static const pageSize = 12;
  @override
  void initState() {
    super.initState();
    loading = _load();
    checklistTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  Future<void> _load() async {
    final requests = <Future<dynamic>>[
      api.get(
        '/api/company/digital-checklist/data',
        query: {'menuCode': widget.menuCode},
      ),
      api.get('/api/company/digital-checklist/actions/${widget.menuCode}'),
    ];
    if (const {
      '58002',
      '58003',
      '58004',
      '58005',
      '58006',
    }.contains(widget.menuCode)) {
      requests.add(
        api.get(
          '/api/company/digital-checklist/options',
          query: {'menuCode': widget.menuCode},
        ),
      );
    }
    if (widget.menuCode == '58006') {
      requests.add(api.get('/api/company/digital-checklist/notifications'));
    }
    if (widget.menuCode == '58004') {
      requests.add(
        api.get('/api/company/digital-checklist/approver-directory'),
      );
    }
    final values = await Future.wait(requests);
    final data = values[0], permission = values[1];
    if (!mounted) return;
    setState(() {
      rows = data is List
          ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : data is Map
          ? [Map<String, dynamic>.from(data)]
          : [];
      actions = permission is Map && permission['actions'] is Map
          ? Map<String, dynamic>.from(permission['actions'] as Map)
          : {};
      options = values.length > 2 && values[2] is Map
          ? Map<String, dynamic>.from(values[2] as Map)
          : {};
      notices = values.length > 3 && values[3] is List
          ? (values[3] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : [];
      if (widget.menuCode == '58004' &&
          values.length > 3 &&
          values[3] is List) {
        options['approvers'] = values[3];
      }
    });
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      loading = _load();
    });
  }

  @override
  void dispose() {
    disposeChecklistApi(api);
    super.dispose();
  }

  List<Map<String, dynamic>> get allRows {
    final data = [...rows];
    if (widget.menuCode == '58002') {
      for (final type in _optionRows('types')) {
        final group = rows.where((row) => row['id'] == type['groupId']);
        data.add({
          ...type,
          'entityCode': 'TYPE',
          'groupName': group.isEmpty ? '—' : group.first['name'],
        });
      }
    }
    return data;
  }

  List<Map<String, dynamic>> get visible {
    final q = search.trim().toLowerCase();
    final list = allRows
        .where(
          (r) =>
              q.isEmpty || r.values.any((v) => '$v'.toLowerCase().contains(q)),
        )
        .toList();
    final from = (page - 1) * pageSize;
    return list.skip(from).take(pageSize).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = checklistTokens;
    return checklistShell(
      title: title,
      menu: widget.menuCode,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Padding(
            padding: t.contentMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LaooCaptionCard(
                  tokens: t,
                  caption: title,
                  favoriteKey: widget.menuCode,
                  leading: const Icon(Icons.fact_check_outlined, size: 24),
                  trailing: widget.menuCode == '58010'
                      ? null
                      : Wrap(
                          spacing: 8,
                          children: [
                            if (!compact)
                              IconButton(
                                tooltip: 'รายการ',
                                onPressed: () => setState(() => cards = false),
                                icon: const Icon(Icons.view_list),
                              ),
                            if (!compact)
                              IconButton(
                                tooltip: 'การ์ด',
                                onPressed: () => setState(() => cards = true),
                                icon: const Icon(Icons.grid_view),
                              ),
                            if (widget.menuCode == '58002' &&
                                actions['create'] == true)
                              OutlinedButton.icon(
                                onPressed: _createType,
                                icon: const Icon(Icons.account_tree_outlined),
                                label: const Text('เพิ่มประเภท'),
                              ),
                            if (widget.menuCode == '58001' &&
                                actions['edit'] == true)
                              FilledButton.icon(
                                onPressed: _editSettings,
                                icon: const Icon(Icons.tune),
                                label: const Text('ตั้งค่า'),
                              ),
                            if (actions['create'] == true)
                              FilledButton.icon(
                                onPressed: _create,
                                icon: const Icon(Icons.add),
                                label: const Text('เพิ่ม'),
                              ),
                          ],
                        ),
                ),
                SizedBox(height: t.sectionSpacing),
                if (widget.menuCode == '58010') _dashboard(t) else _filters(t),
                if (widget.menuCode == '58006' && notices.isNotEmpty) ...[
                  SizedBox(height: t.sectionSpacing),
                  _notificationCard(t),
                ],
                SizedBox(height: t.sectionSpacing),
                Expanded(
                  child: FutureBuilder<void>(
                    future: loading,
                    builder: (context, s) {
                      if (s.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (s.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('โหลดข้อมูลไม่สำเร็จ'),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _reload(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('ลองอีกครั้ง'),
                              ),
                            ],
                          ),
                        );
                      }
                      return _content(t, compact: compact);
                    },
                  ),
                ),
                if (widget.menuCode != '58010')
                  LaooPaginationCard(
                    tokens: t,
                    page: page,
                    pageCount: (allRows.length / pageSize).ceil().clamp(1, 999),
                    pageSize: pageSize,
                    total: allRows.length,
                    onPrevious: page > 1 ? () => setState(() => page--) : null,
                    onNext: page * pageSize < allRows.length
                        ? () => setState(() => page++)
                        : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filters(LaooWorkspaceUiTokens t) => LaooSurfaceCard(
    tokens: t,
    child: TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'ค้นหารหัสหรือชื่อ',
        border: OutlineInputBorder(),
      ),
      onChanged: (v) => setState(() {
        search = v;
        page = 1;
      }),
    ),
  );

  Widget _notificationCard(LaooWorkspaceUiTokens t) => LaooSurfaceCard(
    tokens: t,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('การแจ้งเตือน', style: t.sectionStyle),
        const SizedBox(height: 8),
        ...notices
            .take(3)
            .map(
              (notice) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: t.primaryColor,
                ),
                title: Text('${notice['message'] ?? 'มีรายการใหม่'}'),
                subtitle: Text('${notice['createdAt'] ?? ''}'),
              ),
            ),
      ],
    ),
  );
  Widget _content(LaooWorkspaceUiTokens t, {required bool compact}) {
    if (allRows.isEmpty) {
      return Center(
        child: Text(
          'ยังไม่มีข้อมูลในหน้านี้',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    final data = visible;
    return cards || compact
        ? compact
              ? ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, _) => SizedBox(height: t.itemSpacing),
                  itemBuilder: (context, i) => _rowCard(data[i], t),
                )
              : LayoutBuilder(
                  builder: (context, c) => GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: c.maxWidth < 600
                          ? 1
                          : c.maxWidth < 1000
                          ? 2
                          : 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: c.maxWidth < 600 ? 2.6 : 2.0,
                    ),
                    itemCount: data.length,
                    itemBuilder: (context, i) => _rowCard(data[i], t),
                  ),
                )
        : LaooSurfaceCard(
            tokens: t,
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, c) {
                final keys = _keys(data);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: DataTable(
                      columns:
                          keys
                              .map((k) => DataColumn(label: Text(_label(k))))
                              .toList()
                            ..addAll(
                              _hasRowAction
                                  ? const [DataColumn(label: Text('จัดการ'))]
                                  : const [],
                            ),
                      rows: data
                          .map(
                            (r) => DataRow(
                              cells: [
                                ...keys.map((k) => DataCell(Text(_text(r[k])))),
                                if (_hasRowAction) DataCell(_rowAction(r)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          );
  }

  List<String> _keys(List<Map<String, dynamic>> data) => data.first.keys
      .where(
        (k) => !{'departmentId', 'groupId', 'typeId', 'isActive'}.contains(k),
      )
      .take(6)
      .toList();
  bool get _hasRowAction =>
      const {'58002', '58003', '58004', '58005'}.contains(widget.menuCode) ||
      widget.menuCode == '58006' ||
      widget.menuCode == '58007' ||
      widget.menuCode == '58008';
  Widget _rowAction(Map<String, dynamic> row) {
    if (widget.menuCode == '58006') {
      final status = '${row['status']}';
      final id = (row['id'] as num).toInt();
      final canStart =
          actions['submit'] == true &&
          {'DUE', 'OVERDUE', 'RETURNED'}.contains(status) &&
          row['scheduleId'] != null;
      return Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'บันทึกผลตรวจ',
            onPressed: canStart ? () => _createInspection(schedule: row) : null,
            icon: const Icon(Icons.play_circle_outline),
          ),
          if (actions['create'] == true && row['canUploadEvidence'] == true)
            IconButton(
              tooltip: 'แนบรูปหลักฐานที่ค้าง',
              onPressed: uploadingEvidence.contains(id)
                  ? null
                  : () => _uploadMissingEvidence(id),
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
        ],
      );
    }
    if (const {'58002', '58003', '58004', '58005'}.contains(widget.menuCode)) {
      final entity =
          '${row['entityCode'] ?? (widget.menuCode == '58002'
                  ? 'GROUP'
                  : widget.menuCode == '58003'
                  ? 'TEMPLATE'
                  : widget.menuCode == '58004'
                  ? 'WORKFLOW'
                  : 'SCHEDULE')}';
      return Wrap(
        spacing: 2,
        children: [
          if (actions['edit'] == true)
            IconButton(
              tooltip: 'แก้ไข',
              onPressed: () => _editMaster(row, entity),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (actions['delete'] == true)
            IconButton(
              tooltip: 'ลบ',
              onPressed: () => _deleteMaster(row, entity),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      );
    }
    if (widget.menuCode == '58007') {
      return Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'อนุมัติ',
            onPressed: actions['approve'] == true
                ? () => _runRowAction(row, 'APPROVE')
                : null,
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          ),
          IconButton(
            tooltip: 'ส่งกลับ',
            onPressed: actions['return'] == true
                ? () => _runRowAction(row, 'RETURN')
                : null,
            icon: const Icon(Icons.reply, color: Colors.orange),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'ส่งแจ้งซ่อม',
          onPressed: actions['handoff'] == true
              ? () => _runRowAction(row, 'HANDOFF')
              : null,
          icon: const Icon(Icons.build_outlined),
        ),
        IconButton(
          tooltip: 'ปิดงาน',
          onPressed: actions['edit'] == true
              ? () => _runRowAction(row, 'RESOLVE')
              : null,
          icon: const Icon(Icons.task_alt),
        ),
      ],
    );
  }

  Future<void> _editMaster(Map<String, dynamic> row, String entity) async {
    final code = TextEditingController(text: '${row['code'] ?? ''}');
    final name = TextEditingController(
      text: '${row['name'] ?? row['subject'] ?? ''}',
    );
    final value = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('$title > แก้ไข'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entity != 'WORKFLOW' && entity != 'SCHEDULE')
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'รหัส'),
              ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'ชื่อ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'code': code.text.trim(),
              'name': name.text.trim(),
            }),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (value == null || !mounted || value['name']!.isEmpty) return;
    final id = (row['id'] as num).toInt();
    final payload = <String, dynamic>{'name': value['name']};
    if (entity != 'WORKFLOW' && entity != 'SCHEDULE') {
      payload['code'] = value['code'];
    }
    await _save(
      '/api/company/digital-checklist/masters/$entity/$id',
      payload,
      update: true,
    );
  }

  Future<void> _deleteMaster(Map<String, dynamic> row, String entity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: Colors.red,
          size: 30,
        ),
        title: const Text(
          'ยืนยันปิดใช้งาน',
          style: TextStyle(color: Colors.red),
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffffeeee),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${row['code'] ?? ''} ${row['name'] ?? ''}\nรายการจะถูกปิดใช้งานและไม่ถูกลบประวัติ ไม่สามารถเรียกคืนด้วยการลบถาวร',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ปิดใช้งาน'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final id = (row['id'] as num).toInt();
      await api.delete('/api/company/digital-checklist/masters/$entity/$id');
      if (!mounted) return;
      checklistMessage(context, message: 'ปิดใช้งานรายการแล้ว');
      _reload();
    } catch (error) {
      if (mounted) checklistMessage(context, message: '$error', error: true);
    }
  }

  Future<void> _runRowAction(Map<String, dynamic> row, String action) async {
    String? note;
    if (action == 'RETURN') {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('ส่งกลับแก้ไข'),
          content: TextField(
            controller: c,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'เหตุผล'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('ส่งกลับ'),
            ),
          ],
        ),
      );
      if (note == null || note.trim().isEmpty || !mounted) return;
    }
    try {
      final id = row['id'];
      if (action == 'APPROVE') {
        await api.post(
          '/api/company/digital-checklist/approvals/$id/approve',
          body: {'note': note},
        );
      } else if (action == 'RETURN') {
        await api.post(
          '/api/company/digital-checklist/approvals/$id/return',
          body: {'note': note},
        );
      } else if (action == 'HANDOFF') {
        await api.post('/api/company/digital-checklist/corrective/$id/handoff');
      } else {
        await api.post(
          '/api/company/digital-checklist/corrective/$id/status',
          body: {'statusCode': 'RESOLVED'},
        );
      }
      if (!mounted) return;
      checklistMessage(
        context,
        message: action == 'APPROVE'
            ? 'อนุมัติแล้ว'
            : action == 'RETURN'
            ? 'ส่งกลับแล้ว'
            : action == 'HANDOFF'
            ? 'ส่งแจ้งซ่อมแล้ว'
            : 'ปิดงานแล้ว',
      );
      _reload();
    } catch (e) {
      if (mounted) {
        checklistMessage(context, message: e.toString(), error: true);
      }
    }
  }

  String _label(String k) =>
      const {
        'id': 'ID',
        'code': 'รหัส',
        'name': 'ชื่อ',
        'group': 'กลุ่ม',
        'department': 'แผนก',
        'type': 'ประเภท',
        'frequency': 'ความถี่',
        'dueAt': 'กำหนดตรวจ',
        'submittedAt': 'ส่งเมื่อ',
        'status': 'สถานะ',
        'subject': 'รายละเอียด',
        'pending': 'รออนุมัติ',
        'overdue': 'เกินกำหนด',
        'corrective': 'งานแก้ไข',
        'today': 'วันนี้',
        'action': 'กิจกรรม',
        'createdAt': 'วันที่',
        'entityCode': 'ชนิด',
        'groupName': 'กลุ่มแม่',
      }[k] ??
      k;
  String _text(dynamic v) => v == 'GROUP'
      ? 'กลุ่ม'
      : v == 'TYPE'
      ? 'ประเภท'
      : v == null
      ? '—'
      : v is DateTime
      ? v.toLocal().toString()
      : v.toString();
  Widget _rowCard(Map<String, dynamic> row, LaooWorkspaceUiTokens t) =>
      LaooSurfaceCard(
        tokens: t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...row.entries
                .where(
                  (e) => !{
                    'isActive',
                    'departmentId',
                    'groupId',
                    'scheduleId',
                    'typeId',
                    'canUploadEvidence',
                    'version',
                  }.contains(e.key),
                )
                .take(4)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${_label(e.key)}: ${_text(e.value)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            if (_hasRowAction)
              Align(alignment: Alignment.centerRight, child: _rowAction(row)),
          ],
        ),
      );
  Widget _dashboard(LaooWorkspaceUiTokens t) {
    final r = rows.isEmpty ? <String, dynamic>{} : rows.first;
    final entries = {
      'งานวันนี้': r['today'] ?? 0,
      'รออนุมัติ': r['pending'] ?? 0,
      'เกินกำหนด': r['overdue'] ?? 0,
      'งานแก้ไข': r['corrective'] ?? 0,
    }.entries.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries
          .map(
            (e) => SizedBox(
              width: 240,
              child: LaooSurfaceCard(
                tokens: t,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: t.sectionStyle),
                    const SizedBox(height: 12),
                    Text(
                      '${e.value}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: t.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<Map<String, dynamic>> _optionRows(String key) => options[key] is List
      ? (options[key] as List)
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .toList()
      : <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _uniqueById(List<Map<String, dynamic>> values) {
    final seen = <int>{};
    return values
        .where((value) => seen.add((value['id'] as num).toInt()))
        .toList();
  }

  Future<void> _createType() async {
    final groups = _optionRows('groups');
    if (groups.isEmpty) {
      checklistMessage(
        context,
        message: 'เพิ่มกลุ่มก่อนสร้างประเภท',
        error: true,
      );
      return;
    }
    final code = TextEditingController(), name = TextEditingController();
    int? groupId = (groups.first['id'] as num).toInt();
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('เพิ่มประเภทตรวจ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: groupId,
                decoration: const InputDecoration(labelText: 'กลุ่ม'),
                items: groups
                    .map(
                      (g) => DropdownMenuItem(
                        value: (g['id'] as num).toInt(),
                        child: Text('${g['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => groupId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'รหัสประเภท'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อประเภท'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'parentId': groupId,
                'code': code.text.trim(),
                'name': name.text.trim(),
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (values == null || !mounted) return;
    await _save('/api/company/digital-checklist/types', {
      'parentId': values['parentId'],
      'code': values['code'],
      'name': values['name'],
    });
  }

  Future<void> _createTemplate() async {
    final types = _optionRows('types');
    if (types.isEmpty) {
      checklistMessage(
        context,
        message: 'ยังไม่มีประเภทตรวจ กรุณาสร้างประเภทก่อน',
        error: true,
      );
      return;
    }
    final code = TextEditingController(),
        name = TextEditingController(),
        items = TextEditingController();
    int? typeId = (types.first['id'] as num).toInt();
    final v = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('เพิ่มแบบตรวจ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: typeId,
                  decoration: const InputDecoration(labelText: 'ประเภท'),
                  items: types
                      .map(
                        (x) => DropdownMenuItem(
                          value: (x['id'] as num).toInt(),
                          child: Text('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (x) => setLocal(() => typeId = x),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'รหัสแบบตรวจ'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'ชื่อแบบตรวจ'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: items,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'รายการตรวจ (หนึ่งรายการต่อบรรทัด)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'parentId': typeId,
                'code': code.text.trim(),
                'name': name.text.trim(),
                'details': items.text,
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    await _save('/api/company/digital-checklist/master', {
      'menuCode': '58003',
      ...v,
    });
  }

  Future<void> _save(
    String path,
    Map<String, dynamic> body, {
    bool update = false,
  }) async {
    try {
      if (update) {
        await api.put(path, body: body);
      } else {
        await api.post(path, body: body);
      }
      if (!mounted) return;
      checklistMessage(context, message: 'บันทึกสำเร็จ');
      _reload();
    } catch (e) {
      if (mounted) {
        checklistMessage(context, message: e.toString(), error: true);
      }
    }
  }

  Future<void> _editSettings() async {
    final current = rows.isEmpty ? <String, dynamic>{} : rows.first;
    bool inApp = current['NotifyInApp'] == true;
    bool email = current['NotifyEmail'] == true;
    String zone = '${current['TimeZoneId'] ?? 'Asia/Bangkok'}';
    final minutes = TextEditingController(
      text: '${current['ReminderMinutes'] ?? 60}',
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text('$title > ตั้งค่า'),
          content: SizedBox(
            width: _checklistDialogWidth(ctx, 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: zone,
                  decoration: const InputDecoration(labelText: 'เขตเวลา'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Asia/Bangkok',
                      child: Text('ประเทศไทย'),
                    ),
                    DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                  ],
                  onChanged: (value) => setLocal(() => zone = value ?? zone),
                ),
                TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'เตือนก่อนถึงกำหนด (นาที)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: inApp,
                  title: const Text('แจ้งเตือนในระบบ'),
                  onChanged: (value) => setLocal(() => inApp = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: email,
                  title: const Text('แจ้งเตือนทางอีเมล'),
                  onChanged: (value) => setLocal(() => email = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'timeZoneId': zone,
                'notifyInApp': inApp,
                'notifyEmail': email,
                'reminderMinutes': int.tryParse(minutes.text) ?? -1,
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await api.put('/api/company/digital-checklist/settings', body: result);
      if (!mounted) return;
      checklistMessage(context, message: 'บันทึกการตั้งค่าแล้ว');
      _reload();
    } catch (error) {
      if (mounted) checklistMessage(context, message: '$error', error: true);
    }
  }

  Future<void> _createWorkflow() async {
    final types = _optionRows('types');
    if (types.isEmpty) {
      checklistMessage(context, message: 'สร้างประเภทตรวจก่อน', error: true);
      return;
    }
    final name = TextEditingController();
    final users = _optionRows('approvers');
    final selectedUsers = <int>[];
    if (users.isEmpty) {
      checklistMessage(
        context,
        message: 'ไม่พบรายชื่อผู้อนุมัติในบริษัท',
        error: true,
      );
      return;
    }
    int? type = (types.first['id'] as num).toInt();
    final v = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, local) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('กำหนดสายอนุมัติ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'ประเภทตรวจ'),
                items: types
                    .map(
                      (e) => DropdownMenuItem(
                        value: (e['id'] as num).toInt(),
                        child: Text('${e['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: (x) => local(() => type = x),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อสายอนุมัติ'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                width: _checklistDialogWidth(ctx, 440),
                child: ListView(
                  children: _uniqueById(users).map((user) {
                    final id = (user['id'] as num).toInt();
                    final order = selectedUsers.indexOf(id);
                    return CheckboxListTile(
                      value: order >= 0,
                      title: Text(
                        order < 0
                            ? '${user['name']}'
                            : '${order + 1}. ${user['name']}',
                      ),
                      subtitle: Text(
                        '${user['department'] ?? user['code'] ?? ''}',
                      ),
                      onChanged: (checked) => local(() {
                        if (checked == true && !selectedUsers.contains(id)) {
                          selectedUsers.add(id);
                        } else {
                          selectedUsers.remove(id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'type': '$type',
                'name': name.text.trim(),
                'users': selectedUsers.toList(),
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    final ids = (v['users'] as List).cast<int>();
    if (ids.isEmpty) {
      checklistMessage(
        context,
        message: 'เลือกผู้อนุมัติอย่างน้อยหนึ่งคน',
        error: true,
      );
      return;
    }
    await _save('/api/company/digital-checklist/workflows', {
      'parentId': int.parse(v['type']!),
      'name': v['name'],
      'details': jsonEncode(ids),
    });
  }

  Future<void> _createSchedule() async {
    final types = _optionRows('types');
    final employees = _optionRows('employees');
    if (types.isEmpty) {
      checklistMessage(context, message: 'สร้างประเภทตรวจก่อน', error: true);
      return;
    }
    if (employees.isEmpty) {
      checklistMessage(
        context,
        message: 'ไม่มีพนักงานที่มีแผนกปัจจุบันสำหรับรับผิดชอบแผนตรวจ',
        error: true,
      );
      return;
    }
    final name = TextEditingController(),
        times = TextEditingController(text: '08:00,16:00'),
        weekdays = TextEditingController(text: '1');
    int? type = (types.first['id'] as num).toInt();
    int? responsibleEmployee = (employees.first['id'] as num).toInt();
    String frequency = 'DAILY';
    final v = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, local) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('กำหนดแผนตรวจ'),
          content: SizedBox(
            width: _checklistDialogWidth(ctx, 440),
            height: (MediaQuery.sizeOf(ctx).height - 220).clamp(120.0, 430.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'ประเภทตรวจ'),
                    items: types
                        .map(
                          (e) => DropdownMenuItem(
                            value: (e['id'] as num).toInt(),
                            child: Text('${e['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (x) => local(() => type = x),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: responsibleEmployee,
                    decoration: const InputDecoration(
                      labelText: 'พนักงานผู้รับผิดชอบ',
                    ),
                    items: employees
                        .map(
                          (e) => DropdownMenuItem(
                            value: (e['id'] as num).toInt(),
                            child: Text(
                              '${e['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (x) => local(() => responsibleEmployee = x),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'ชื่อแผนตรวจ'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'รอบความถี่'),
                    items: const ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (x) => local(() => frequency = x ?? 'DAILY'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: times,
                    decoration: const InputDecoration(
                      labelText: 'เวลาตรวจ (คั่นด้วย ,)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weekdays,
                    decoration: const InputDecoration(
                      labelText: 'วันตรวจรายสัปดาห์ (1=จันทร์ ถึง 7=อาทิตย์)',
                      helperText: 'ใส่เลขคั่นด้วยจุลภาค เช่น 1,3,5',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'type': '$type',
                'employee': '$responsibleEmployee',
                'name': name.text.trim(),
                'frequency': frequency,
                'times': times.text,
                'weekdays': weekdays.text,
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    await _save('/api/company/digital-checklist/schedules', {
      'parentId': int.parse(v['type']!),
      'responsibleEmployeeId': int.parse(v['employee']!),
      'name': v['name'],
      'frequency': v['frequency'],
      'timesJson': jsonEncode(
        v['times']!.split(',').map((s) => s.trim()).toList(),
      ),
      'weekDaysJson': jsonEncode(
        v['weekdays']!
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList(),
      ),
    });
  }

  Future<void> _uploadMissingEvidence(int inspectionId) async {
    if (uploadingEvidence.contains(inspectionId)) return;
    setState(() => uploadingEvidence.add(inspectionId));
    try {
      final raw = await api.get(
        '/api/company/digital-checklist/inspections/$inspectionId/items',
      );
      final missing = raw is List
          ? raw
                .whereType<Map>()
                .where(
                  (item) =>
                      item['resultCode'] == 'FAIL' &&
                      item['attachmentId'] == null,
                )
                .toList()
          : <Map>[];
      for (final item in missing) {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        final file = picked?.files.single;
        if (file?.bytes == null) return;
        await uploadChecklistEvidence(
          '/api/company/digital-checklist/inspections/$inspectionId/items/${item['id']}/evidence',
          fileName: file!.name,
          bytes: file.bytes!,
          fields: const {},
        );
      }
      if (!mounted) return;
      checklistMessage(context, message: 'แนบรูปหลักฐานเรียบร้อย');
      _reload();
    } catch (_) {
      if (mounted) {
        checklistMessage(
          context,
          message: 'แนบรูปไม่สำเร็จ กรุณาตรวจชนิดและขนาดภาพแล้วลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => uploadingEvidence.remove(inspectionId));
    }
  }

  Future<void> _createInspection({Map<String, dynamic>? schedule}) async {
    final types = _optionRows('types');
    if (types.isEmpty) {
      checklistMessage(context, message: 'ยังไม่มีประเภทตรวจ', error: true);
      return;
    }
    int? typeId =
        (schedule?['typeId'] as num?)?.toInt() ??
        (types.first['id'] as num).toInt();
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, local) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('เริ่มบันทึกผลตรวจ'),
          content: DropdownButtonFormField<int>(
            initialValue: typeId,
            decoration: const InputDecoration(labelText: 'ประเภทตรวจ'),
            items: types
                .map(
                  (e) => DropdownMenuItem(
                    value: (e['id'] as num).toInt(),
                    child: Text('${e['name']}'),
                  ),
                )
                .toList(),
            onChanged: schedule == null ? (v) => local(() => typeId = v) : null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, typeId),
              child: const Text('ถัดไป'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      final raw = await api.get(
        '/api/company/digital-checklist/types/$selected/template-items',
        query: schedule == null
            ? const {}
            : {'scheduleId': '${schedule['scheduleId']}'},
      );
      if (!mounted) return;
      final items = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (items.isEmpty) {
        checklistMessage(
          context,
          message: 'ประเภทนี้ยังไม่มีรายการแบบตรวจ',
          error: true,
        );
        return;
      }
      final statuses = <int, String>{
        for (final item in items) (item['id'] as num).toInt(): 'PASS',
      };
      final notes = <int, TextEditingController>{
        for (final item in items)
          (item['id'] as num).toInt(): TextEditingController(),
      };
      final result = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, local) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: const Text('บันทึกผลตรวจ'),
            content: SizedBox(
              width: _checklistDialogWidth(ctx, 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((item) {
                    final id = (item['id'] as num).toInt();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${item['text']}',
                            style: Theme.of(ctx).textTheme.titleSmall,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: statuses[id],
                            decoration: const InputDecoration(
                              labelText: 'ผลตรวจ',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'PASS',
                                child: Text('ผ่าน'),
                              ),
                              DropdownMenuItem(
                                value: 'FAIL',
                                child: Text('ไม่ผ่าน'),
                              ),
                            ],
                            onChanged: (v) =>
                                local(() => statuses[id] = v ?? 'PASS'),
                          ),
                          TextField(
                            controller: notes[id],
                            decoration: const InputDecoration(
                              labelText: 'รายละเอียด',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  items.map((item) {
                    final id = (item['id'] as num).toInt();
                    return {
                      'templateItemId': id,
                      'resultCode': statuses[id],
                      'detail': notes[id]!.text.trim(),
                    };
                  }).toList(),
                ),
                child: const Text('ส่งตรวจ'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      final evidence = <int, PlatformFile>{};
      for (final failed in result.where(
        (item) => item['resultCode'] == 'FAIL',
      )) {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        final file = picked?.files.single;
        if (file?.bytes == null) {
          if (mounted) {
            checklistMessage(
              context,
              message: 'ข้อที่ไม่ผ่านต้องแนบรูปหลักฐานก่อนส่งตรวจ',
              error: true,
            );
          }
          return;
        }
        evidence[(failed['templateItemId'] as num).toInt()] = file!;
      }
      final inspectionBody = {
        'typeId': selected,
        'items': result,
        'note': '',
        if (schedule != null) 'inspectionId': schedule['id'],
      };
      final response = await api.post(
        schedule == null
            ? '/api/company/digital-checklist/inspections'
            : '/api/company/digital-checklist/schedules/${schedule['scheduleId']}/inspections',
        body: inspectionBody,
      );
      final inspectionId = (response as Map)['id'] as num;
      final savedItems =
          await api.get(
                '/api/company/digital-checklist/inspections/${inspectionId.toInt()}/items',
              )
              as List;
      for (final failed in result.where(
        (item) => item['resultCode'] == 'FAIL',
      )) {
        final saved = savedItems.cast<Map>().firstWhere(
          (item) => item['templateItemId'] == failed['templateItemId'],
        );
        final file = evidence[(failed['templateItemId'] as num).toInt()]!;
        await uploadChecklistEvidence(
          '/api/company/digital-checklist/inspections/${inspectionId.toInt()}/items/${(saved['id'] as num).toInt()}/evidence',
          fileName: file.name,
          bytes: file.bytes!,
          fields: const {},
        );
      }
      if (!mounted) return;
      checklistMessage(context, message: 'ส่งผลตรวจและหลักฐานเรียบร้อย');
      _reload();
    } catch (e) {
      if (mounted) {
        checklistMessage(context, message: e.toString(), error: true);
      }
    }
  }

  Future<void> _create() async {
    if (widget.menuCode == '58003') return _createTemplate();
    if (widget.menuCode == '58004') return _createWorkflow();
    if (widget.menuCode == '58005') return _createSchedule();
    if (widget.menuCode == '58006') return _createInspection();
    final code = TextEditingController(), name = TextEditingController();
    final departments = _optionRows('departments');
    int? departmentId = departments.isEmpty
        ? null
        : (departments.first['id'] as num).toInt();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, local) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text('$title > เพิ่ม'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'รหัส'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อรายการ'),
              ),
              if (widget.menuCode == '58002' &&
                  actions['manage_department'] == true &&
                  departments.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: departmentId,
                  decoration: const InputDecoration(labelText: 'แผนกรับผิดชอบ'),
                  items: departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: (d['id'] as num).toInt(),
                          child: Text('${d['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => local(() => departmentId = value),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'code': code.text.trim(),
                'name': name.text.trim(),
                if (departmentId != null) 'departmentId': departmentId,
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    if (result['name']!.isEmpty) {
      checklistMessage(context, message: 'กรุณากรอกชื่อรายการ', error: true);
      return;
    }
    try {
      await api.post(
        '/api/company/digital-checklist/master',
        body: {
          'menuCode': widget.menuCode,
          'code': result['code'],
          'name': result['name'],
          if (result['departmentId'] != null)
            'departmentId': result['departmentId'],
        },
      );
      if (mounted) {
        checklistMessage(context, message: 'บันทึกสำเร็จ');
        _reload();
      }
    } catch (e) {
      if (mounted) {
        checklistMessage(context, message: e.toString(), error: true);
      }
    }
  }
}

double _checklistDialogWidth(BuildContext context, double maxWidth) =>
    (MediaQuery.sizeOf(context).width - 80).clamp(240.0, maxWidth).toDouble();
