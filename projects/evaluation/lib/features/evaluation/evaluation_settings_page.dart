import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';
import 'evaluation_setting_dialog.dart';

class EvaluationSettingsPage extends StatefulWidget {
  const EvaluationSettingsPage({super.key, required this.title});
  final String title;

  @override
  State<EvaluationSettingsPage> createState() => _EvaluationSettingsPageState();
}

class _EvaluationSettingsPageState extends State<EvaluationSettingsPage> {
  late final JsonApiClient _api;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  String _source = 'ALL';
  String _status = 'ALL';
  int _page = 1;
  bool _loading = true;
  bool _canCreate = false, _canEdit = false, _canDelete = false;

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/settings') as Map,
      );
      final permissions = Map<String, dynamic>.from(
        raw['permissions'] as Map? ?? {},
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(raw['items'] as List? ?? []);
        _canCreate = permissions['create'] == true;
        _canEdit = permissions['edit'] == true;
        _canDelete = permissions['delete'] == true;
      });
    } catch (e) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message: 'ไม่สามารถโหลดข้อมูลได้\nรายละเอียดเพิ่มเติม: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save([Map<String, dynamic>? item]) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EvaluationSettingDialog(initial: item),
    );
    if (request == null) return;
    try {
      final id = (item?['id'] as num?)?.toInt();
      if (id == null) {
        await _api.post('/api/company/evaluations/settings', body: request);
      } else {
        await _api.put('/api/company/evaluations/settings/$id', body: request);
      }
      if (!mounted) return;
      showEvaluationMessage(
        context,
        message: id == null ? 'เพิ่มการตั้งค่าสำเร็จ' : 'แก้ไขการตั้งค่าสำเร็จ',
      );
      await _load();
    } catch (e) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message: 'บันทึกข้อมูลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _view(Map<String, dynamic> item) => showDialog<void>(
    context: context,
    builder: (_) => EvaluationSettingDialog(initial: item, readOnly: true),
  );

  Future<void> _delete(Map<String, dynamic> item) async {
    final label =
        evaluationSourceLabels[item['sourceType']] ?? '${item['sourceType']}';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text(
          'ลบการตั้งค่าระบบประเมิน',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text(label),
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
      await _api.delete('/api/company/evaluations/settings/${item['id']}');
      if (!mounted) return;
      showEvaluationMessage(context, message: 'ลบการตั้งค่าสำเร็จ');
      await _load();
    } catch (e) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message: 'ลบข้อมูลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $e',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _items.where((x) {
      final active = x['isActive'] == true;
      return (_source == 'ALL' || x['sourceType'] == _source) &&
          (_status == 'ALL' || (_status == 'ACTIVE') == active) &&
          (query.isEmpty ||
              '${x['sourceType']} ${x['templateName']}'.toLowerCase().contains(
                query,
              ));
    }).toList();
    const pageSize = 10;
    final pageCount = (filtered.length / pageSize).ceil().clamp(1, 9999);
    if (_page > pageCount) _page = pageCount;
    final start = (_page - 1) * pageSize;
    final rows = filtered.skip(start).take(pageSize).toList();
    return buildEvaluationWorkspaceShell(
      pageTitle: widget.title,
      activeMenu: '47001',
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _load,
                      tooltip: 'โหลดข้อมูลล่าสุด',
                      icon: const Icon(Icons.refresh),
                    ),
                    if (_canCreate)
                      FilledButton.icon(
                        onPressed: () => _save(),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'ค้นหาประเภทงานหรือแบบประเมิน',
                        ),
                        onSubmitted: (_) => setState(() => _page = 1),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        initialValue: _source,
                        decoration: const InputDecoration(
                          labelText: 'ประเภทงาน',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'ALL',
                            child: Text('ทั้งหมด'),
                          ),
                          ...evaluationSourceLabels.entries.map(
                            (x) => DropdownMenuItem(
                              value: x.key,
                              child: Text(x.value),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _source = v ?? 'ALL';
                          _page = 1;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'สถานะ'),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text('ทั้งหมด'),
                          ),
                          DropdownMenuItem(
                            value: 'ACTIVE',
                            child: Text('ใช้งาน'),
                          ),
                          DropdownMenuItem(
                            value: 'INACTIVE',
                            child: Text('ไม่ใช้งาน'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _status = v ?? 'ALL';
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
                        _source = 'ALL';
                        _status = 'ALL';
                        _page = 1;
                      }),
                      icon: const Icon(Icons.clear),
                      label: const Text('ล้าง Filter'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลตั้งค่าระบบประเมิน'))
                  : LayoutBuilder(
                      builder: (_, box) => box.maxWidth < 850
                          ? ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _SettingCard(
                                item: rows[i],
                                canEdit: _canEdit,
                                canDelete: _canDelete,
                                onView: () => _view(rows[i]),
                                onEdit: () => _save(rows[i]),
                                onDelete: () => _delete(rows[i]),
                              ),
                            )
                          : Card(
                              margin: EdgeInsets.zero,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ID')),
                                    DataColumn(label: Text('จัดการ')),
                                    DataColumn(label: Text('ประเภทงาน')),
                                    DataColumn(
                                      label: Text('แบบประเมินเริ่มต้น'),
                                    ),
                                    DataColumn(label: Text('สถานะ')),
                                  ],
                                  rows: rows.indexed.map((entry) {
                                    final x = entry.$2;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text('${start + entry.$1 + 1}'),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                tooltip: 'ดู',
                                                onPressed: () => _view(x),
                                                icon: const Icon(
                                                  Icons.visibility_outlined,
                                                ),
                                              ),
                                              if (_canEdit)
                                                IconButton(
                                                  tooltip: 'แก้ไข',
                                                  onPressed: () => _save(x),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                ),
                                              if (_canDelete)
                                                IconButton(
                                                  tooltip: 'ลบ',
                                                  onPressed: () => _delete(x),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            evaluationSourceLabels[x['sourceType']] ??
                                                '${x['sourceType']}',
                                          ),
                                        ),
                                        DataCell(
                                          Text('${x['templateName'] ?? '-'}'),
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
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
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
                        onPressed: _page < pageCount
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
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.item,
    required this.canEdit,
    required this.canDelete,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> item;
  final bool canEdit, canDelete;
  final VoidCallback onView, onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evaluationSourceLabels[item['sourceType']] ??
                      '${item['sourceType']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('แบบประเมินเริ่มต้น: ${item['templateName'] ?? '-'}'),
                Text(
                  item['isActive'] == true
                      ? 'สถานะ: ใช้งาน'
                      : 'สถานะ: ไม่ใช้งาน',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'ดู',
          ),
          if (canEdit)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
    ),
  );
}
