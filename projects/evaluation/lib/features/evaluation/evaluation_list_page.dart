import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';
import 'evaluation_response_dialog.dart';
import 'evaluation_results_dialog.dart';
import 'evaluation_round_dialog.dart';
import 'evaluation_template_dialog.dart';

class EvaluationListPage extends StatefulWidget {
  const EvaluationListPage({
    super.key,
    required this.menu,
    required this.title,
    required this.path,
  });
  final String menu, title, path;
  @override
  State<EvaluationListPage> createState() => _EvaluationListPageState();
}

class _EvaluationListPageState extends State<EvaluationListPage> {
  late final JsonApiClient _api;
  List<Map<String, dynamic>> _items = [];
  final _search = TextEditingController();
  String _sourceFilter = 'ALL';
  String _roundStatusFilter = 'ALL';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canSubmit = false;
  bool _canApprove = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _api = createEvaluationApiClient();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    disposeEvaluationApiClient(_api);
    super.dispose();
  }

  Widget _templateCrud(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _items
        .where(
          (x) =>
              (_sourceFilter == 'ALL' || x['sourceType'] == _sourceFilter) &&
              (query.isEmpty ||
                  '${x['code']} ${x['name']}'.toLowerCase().contains(query)),
        )
        .toList();
    const size = 10;
    final pages = (filtered.length / size).ceil().clamp(1, 9999);
    if (_page > pages) _page = pages;
    final start = (_page - 1) * size;
    final rows = filtered.skip(start).take(size).toList();
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_canCreate)
                    FilledButton.icon(
                      onPressed: _createTemplate,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => setState(() => _page = 1),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ค้นหารหัสหรือชื่อแบบประเมิน',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _sourceFilter,
                      decoration: const InputDecoration(labelText: 'ประเภทงาน'),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                          value: 'GENERAL',
                          child: Text('ทั่วไป'),
                        ),
                        DropdownMenuItem(
                          value: 'VENDOR',
                          child: Text('Vendor'),
                        ),
                        DropdownMenuItem(
                          value: 'TRAINING_COURSE',
                          child: Text('หลักสูตรอบรม'),
                        ),
                        DropdownMenuItem(
                          value: 'TRAINING_INSTRUCTOR',
                          child: Text('วิทยากร'),
                        ),
                        DropdownMenuItem(
                          value: 'MEETING_ROOM',
                          child: Text('ห้องประชุม'),
                        ),
                        DropdownMenuItem(
                          value: 'SERVICE',
                          child: Text('งานบริการ'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _sourceFilter = v ?? 'ALL';
                        _page = 1;
                      }),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => setState(() => _page = 1),
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _search.clear();
                      _sourceFilter = 'ALL';
                      _page = 1;
                    }),
                    icon: const Icon(Icons.clear),
                    label: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('จัดการ')),
                    DataColumn(label: Text('รหัส')),
                    DataColumn(label: Text('ชื่อแบบประเมิน')),
                    DataColumn(label: Text('ประเภท')),
                  ],
                  rows: rows.indexed.map((e) {
                    final x = e.$2;
                    return DataRow(
                      cells: [
                        DataCell(Text('${start + e.$1 + 1}')),
                        DataCell(
                          Row(
                            children: [
                              if (_canEdit)
                                IconButton(
                                  onPressed: () => _editTemplate(x),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if (_canDelete)
                                IconButton(
                                  onPressed: () => _deleteTemplate(x),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(Text('${x['code'] ?? ''}')),
                        DataCell(Text('${x['name'] ?? ''}')),
                        DataCell(Text('${x['sourceType'] ?? ''}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      child: const Text('<'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(onPressed: null, child: Text('$_page')),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: _page < pages
                          ? () => setState(() => _page++)
                          : null,
                      child: const Text('>'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      filtered.isEmpty
                          ? '0-0 จาก 0'
                          : '${start + 1}-${start + rows.length} จาก ${filtered.length}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _api.get(
        widget.path,
        query: const {'47003', '47006', '47007'}.contains(widget.menu)
            ? {
                'sourceType': _sourceFilter == 'ALL' ? '' : _sourceFilter,
                'status': _roundStatusFilter == 'ALL' ? '' : _roundStatusFilter,
                'page': '$_page',
                'pageSize': '10',
              }
            : null,
      );
      final map = Map<String, dynamic>.from(raw as Map);
      if (mounted) {
        final permissions = Map<String, dynamic>.from(
          map['permissions'] as Map? ?? {},
        );
        setState(() {
          _items = List<Map<String, dynamic>>.from(
            (map['items'] ?? []) as List,
          );
          _total = (map['total'] as num?)?.toInt() ?? _items.length;
          if (widget.menu == '47002' || widget.menu == '47003') {
            _canCreate = permissions['create'] == true;
            _canEdit = permissions['edit'] == true;
            _canDelete = permissions['delete'] == true;
            _canSubmit = permissions['submit'] == true;
          }
          if (widget.menu == '47004') {
            _canApprove = permissions['approve'] == true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTemplate() async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const EvaluationTemplateDialog(),
    );
    if (request == null) return;
    try {
      await _api.post('/api/company/evaluations/templates', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'เพิ่มแบบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'บันทึกแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: รหัสอาจซ้ำ หรือข้อมูลคำถามยังไม่ครบ',
          error: true,
        );
      }
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final initial = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/templates/$id') as Map,
      );
      if (!mounted) return;
      final request = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EvaluationTemplateDialog(initial: initial),
      );
      if (request == null) return;
      await _api.put('/api/company/evaluations/templates/$id', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'แก้ไขแบบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'แก้ไขแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบข้อมูลและสิทธิ์ใช้งาน',
          error: true,
        );
      }
    }
  }

  Future<void> _viewTemplate(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final initial = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/templates/$id') as Map,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            EvaluationTemplateDialog(initial: initial, readOnly: true),
      );
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'เปิดรายละเอียดแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาโหลดข้อมูลล่าสุดแล้วลองอีกครั้ง',
          error: true,
        );
      }
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('ลบแบบประเมิน', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text('${item['code'] ?? item['name'] ?? '-'}'),
            ),
            const SizedBox(height: 12),
            const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนข้อมูลได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/api/company/evaluations/templates/$id');
      if (mounted) {
        showEvaluationMessage(context, message: 'ลบแบบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'ลบแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: รายการอาจถูกนำไปใช้สร้างรอบประเมินแล้ว',
          error: true,
        );
      }
    }
  }

  Future<void> _createRound() async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const EvaluationRoundDialog(),
    );
    if (request == null) return;
    try {
      await _api.post('/api/company/evaluations/rounds', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'บันทึกร่างรอบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'บันทึกรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจ Template ผู้ตอบ และช่วงเวลาที่กำหนด',
          error: true,
        );
      }
    }
  }

  Future<void> _editRound(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/rounds/$id') as Map,
      );
      final document = Map<String, dynamic>.from(detail['document'] as Map);
      document['respondents'] = detail['respondents'];
      if (!mounted) return;
      final request = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EvaluationRoundDialog(initial: document),
      );
      if (request == null) return;
      await _api.put('/api/company/evaluations/rounds/$id', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'แก้ไขร่างรอบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'แก้ไขรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: แก้ไขได้เฉพาะร่างที่ยังไม่ส่งอนุมัติ',
          error: true,
        );
      }
    }
  }

  Future<void> _deleteRound(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text(
          'ลบร่างรอบประเมิน',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text('${item['roundNo'] ?? item['name']}'),
            ),
            const SizedBox(height: 12),
            const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนข้อมูลได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/api/company/evaluations/rounds/$id');
      if (mounted) {
        showEvaluationMessage(context, message: 'ลบร่างรอบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'ลบรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ลบได้เฉพาะร่างที่ยังไม่ส่งอนุมัติ',
          error: true,
        );
      }
    }
  }

  Future<void> _moveRound(Map<String, dynamic> item, String action) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await _api.put('/api/company/evaluations/rounds/$id/$action');
      if (mounted) {
        showEvaluationMessage(
          context,
          message: action == 'submit'
              ? 'ส่งรอบประเมินเพื่ออนุมัติแล้ว'
              : 'อนุมัติและเผยแพร่รอบประเมินแล้ว',
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'ดำเนินการกับรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: สถานะรอบอาจเปลี่ยนแล้ว หรือบัญชีไม่มีสิทธิ์ดำเนินการ',
          error: true,
        );
      }
    }
  }

  Future<void> _approveRound(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final raw = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/rounds/$id') as Map,
      );
      final document = Map<String, dynamic>.from(raw['document'] as Map);
      final respondents = List<Map<String, dynamic>>.from(
        raw['respondents'] as List? ?? [],
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          icon: Icon(
            Icons.verified_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('อนุมัติและเผยแพร่รอบประเมิน'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${document['roundNo']} | ${document['name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Template: ${document['templateCode']} | ${document['templateName']}',
                ),
                Text('ผู้ตอบ: ${respondents.length} คน'),
                const SizedBox(height: 12),
                const Text(
                  'เมื่ออนุมัติแล้ว ระบบจะเปิดรอบประเมินตามช่วงเวลาที่กำหนด และแก้ไขร่างนี้ไม่ได้',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('อนุมัติและเผยแพร่'),
            ),
          ],
        ),
      );
      if (confirmed == true) await _moveRound(item, 'approve');
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'เปิดรายละเอียดรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาโหลดข้อมูลล่าสุด',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => buildEvaluationWorkspaceShell(
    pageTitle: widget.title,
    activeMenu: widget.menu,
    child: widget.menu == '47002'
        ? _templateCrud(context)
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                    if (widget.menu == '47002')
                      FilledButton.icon(
                        onPressed: _loading ? null : _createTemplate,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                    if (widget.menu == '47003' && _canCreate)
                      FilledButton.icon(
                        onPressed: _loading ? null : _createRound,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (const {
                  '47003',
                  '47006',
                  '47007',
                }.contains(widget.menu)) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _sourceFilter,
                              decoration: const InputDecoration(
                                labelText: 'ประเภทงาน',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'GENERAL',
                                  child: Text('ทั่วไป'),
                                ),
                                DropdownMenuItem(
                                  value: 'VENDOR',
                                  child: Text('Vendor'),
                                ),
                                DropdownMenuItem(
                                  value: 'TRAINING_COURSE',
                                  child: Text('หลักสูตรอบรม'),
                                ),
                                DropdownMenuItem(
                                  value: 'TRAINING_INSTRUCTOR',
                                  child: Text('วิทยากร'),
                                ),
                                DropdownMenuItem(
                                  value: 'MEETING_ROOM',
                                  child: Text('ห้องประชุม'),
                                ),
                                DropdownMenuItem(
                                  value: 'SERVICE',
                                  child: Text('งานบริการ'),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _sourceFilter = v ?? 'ALL';
                                _page = 1;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _roundStatusFilter,
                              decoration: const InputDecoration(
                                labelText: 'สถานะ',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'DRAFT',
                                  child: Text('ร่าง'),
                                ),
                                DropdownMenuItem(
                                  value: 'PENDING_APPROVAL',
                                  child: Text('รออนุมัติ'),
                                ),
                                DropdownMenuItem(
                                  value: 'PUBLISHED',
                                  child: Text('เผยแพร่แล้ว'),
                                ),
                                DropdownMenuItem(
                                  value: 'CLOSED',
                                  child: Text('ปิดรอบ'),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _roundStatusFilter = v ?? 'ALL';
                                _page = 1;
                              }),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _sourceFilter = 'ALL';
                                _roundStatusFilter = 'ALL';
                                _page = 1;
                              });
                              _load();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้าง Filter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Text(
                            'ไม่สามารถโหลดข้อมูลได้\n$_error',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _items.isEmpty
                      ? const Center(child: Text('ไม่พบรายการ'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final x = _items[i];
                            return Card(
                              child: ListTile(
                                onTap: widget.menu == '47002'
                                    ? () => _editTemplate(x)
                                    : widget.menu == '47005' &&
                                          x['roundId'] is num
                                    ? () async {
                                        final saved = await showDialog<bool>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) =>
                                              EvaluationResponseDialog(
                                                roundId: (x['roundId'] as num)
                                                    .toInt(),
                                              ),
                                        );
                                        if (saved == true) _load();
                                      }
                                    : (widget.menu == '47006' ||
                                              widget.menu == '47007') &&
                                          x['id'] is num
                                    ? () => showDialog<void>(
                                        context: context,
                                        builder: (_) => EvaluationResultsDialog(
                                          roundId: (x['id'] as num).toInt(),
                                        ),
                                      )
                                    : null,
                                title: Text(
                                  (x['name'] ??
                                          x['roundNo'] ??
                                          x['code'] ??
                                          '-')
                                      .toString(),
                                ),
                                subtitle: Text(
                                  (x['sourceType'] ?? x['referenceTitle'] ?? '')
                                      .toString(),
                                ),
                                trailing: widget.menu == '47002'
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'ดู',
                                            onPressed: () => _viewTemplate(x),
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                            ),
                                          ),
                                          if (_canEdit)
                                            IconButton(
                                              tooltip: 'แก้ไข',
                                              onPressed: () => _editTemplate(x),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          if (_canDelete)
                                            IconButton(
                                              tooltip: 'ลบ',
                                              onPressed: () =>
                                                  _deleteTemplate(x),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                        ],
                                      )
                                    : widget.menu == '47003' &&
                                          x['status'] == 'DRAFT'
                                    ? Wrap(
                                        spacing: 2,
                                        children: [
                                          IconButton(
                                            tooltip: 'แก้ไขร่าง',
                                            onPressed: () => _editRound(x),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'ลบร่าง',
                                            onPressed: () => _deleteRound(x),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                          ),
                                          if (_canSubmit)
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _moveRound(x, 'submit'),
                                              icon: const Icon(
                                                Icons.send_outlined,
                                              ),
                                              label: const Text('ส่งอนุมัติ'),
                                            ),
                                        ],
                                      )
                                    : widget.menu == '47004' &&
                                          x['status'] == 'PENDING_APPROVAL' &&
                                          _canApprove
                                    ? FilledButton.icon(
                                        onPressed: () => _approveRound(x),
                                        icon: const Icon(
                                          Icons.verified_outlined,
                                        ),
                                        label: const Text('อนุมัติ'),
                                      )
                                    : Text((x['status'] ?? '').toString()),
                              ),
                            );
                          },
                        ),
                ),
                if (const {'47003', '47006', '47007'}.contains(widget.menu))
                  Card(
                    margin: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            OutlinedButton(
                              onPressed: _page > 1
                                  ? () {
                                      setState(() => _page--);
                                      _load();
                                    }
                                  : null,
                              child: const Text('<'),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              onPressed: null,
                              child: Text('$_page'),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: _page * 10 < _total
                                  ? () {
                                      setState(() => _page++);
                                      _load();
                                    }
                                  : null,
                              child: const Text('>'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _total == 0
                                  ? '0-0 จาก 0'
                                  : '${(_page - 1) * 10 + 1}-${((_page * 10) > _total) ? _total : _page * 10} จาก $_total',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
