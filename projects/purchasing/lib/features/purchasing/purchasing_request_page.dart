import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'purchasing_feature_host.dart';
import 'purchasing_request_repository.dart';
import 'purchasing_route_contract.dart';

class PurchasingRequestPage extends StatefulWidget {
  const PurchasingRequestPage({super.key});
  @override
  State<PurchasingRequestPage> createState() => _PurchasingRequestPageState();
}

class _PurchasingRequestPageState extends State<PurchasingRequestPage> {
  late final JsonApiClient _client;
  late final PurchasingRequestRepository _repo;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _divisions = const [];
  List<Map<String, dynamic>> _departments = const [];
  List<Map<String, dynamic>> _requesters = const [];
  String? _divisionId, _departmentId, _requesterId;
  bool _loading = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _client = createPurchasingApiClient();
    _repo = PurchasingRequestRepository(_client);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    disposePurchasingApiClient(_client);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repo.list(
        search: _search.text,
        divisionId: _divisionId,
        departmentId: _departmentId,
        requesterId: _requesterId,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(result['items'] as List? ?? const []);
        _divisions = List<Map<String, dynamic>>.from(result['divisions'] as List? ?? const []);
        _departments = List<Map<String, dynamic>>.from(result['departments'] as List? ?? const []);
        _requesters = List<Map<String, dynamic>>.from(result['requesters'] as List? ?? const []);
      });
    } catch (error) {
      if (mounted) showPurchasingMessage(context, message: 'โหลดคำขอจัดซื้อไม่สำเร็จ: $error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? value]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PurchasingRequestDialog(repository: _repo, initial: value),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) => buildPurchasingWorkspaceShell(
        pageTitle: 'คำขอจัดซื้อ',
        activeMenu: PurchasingMenuCodes.requests,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(children: [
              Expanded(child: Text('คำขอจัดซื้อ', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(onPressed: () => _openEditor(), icon: const Icon(Icons.add), label: const Text('สร้างคำขอ')),
            ]),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(width: 260, child: TextField(controller: _search, onSubmitted: (_) => _load(), decoration: const InputDecoration(labelText: 'ค้นหาเลขที่ขอ/รายการ'))),
              _filter('ฝ่าย', _divisionId, _divisions, (v) { setState(() { _divisionId = v; _departmentId = null; _requesterId = null; }); _load(); }),
              _filter('แผนก', _departmentId, _departments, (v) { setState(() { _departmentId = v; _requesterId = null; }); _load(); }),
              _filter('ผู้ขอ', _requesterId, _requesters, (v) { setState(() => _requesterId = v); _load(); }),
              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.search), label: const Text('ค้นหา')),
              OutlinedButton.icon(onPressed: () { _search.clear(); setState(() { _divisionId = null; _departmentId = null; _requesterId = null; _page = 1; }); _load(); }, icon: const Icon(Icons.clear), label: const Text('ล้าง')),
            ]))),
            const SizedBox(height: 8),
            Card(child: _loading ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())) :
              _rows.isEmpty ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('ไม่พบข้อมูล'))) :
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
                DataColumn(label: Text('#')), DataColumn(label: Text('เลขที่ขอ')), DataColumn(label: Text('วันที่ขอ')), DataColumn(label: Text('สถานะ')), DataColumn(label: Text('ผู้รับผิดชอบ')), DataColumn(label: Text('การทำงาน')),
              ], rows: [for (var i = 0; i < _rows.length; i++) DataRow(cells: [
                DataCell(Text('${i + 1}')), DataCell(Text('${_rows[i]['requestNo'] ?? '-'}')), DataCell(Text('${_rows[i]['requestDate'] ?? '-'}')), DataCell(Text('${_rows[i]['statusCode'] ?? 'DRAFT'}')), DataCell(Text('${_rows[i]['responsibleName'] ?? '-'}')), DataCell(IconButton(onPressed: () => _openEditor(_rows[i]), icon: const Icon(Icons.edit_outlined))),
              ])]))),
          ],
        ),
      );

  Widget _filter(String label, String? value, List<Map<String, dynamic>> items, ValueChanged<String?> onChanged) => SizedBox(width: 190, child: DropdownButtonFormField<String>(value: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: [const DropdownMenuItem(value: null, child: Text('ทั้งหมด')), ...items.map((item) => DropdownMenuItem(value: '${item['id']}', child: Text('${item['name']}')))], onChanged: onChanged));
}

class _PurchasingRequestDialog extends StatefulWidget {
  const _PurchasingRequestDialog({required this.repository, this.initial});
  final PurchasingRequestRepository repository;
  final Map<String, dynamic>? initial;
  @override
  State<_PurchasingRequestDialog> createState() => _PurchasingRequestDialogState();
}

class _PurchasingRequestDialogState extends State<_PurchasingRequestDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _remark, _requestDate;
  List<Map<String, dynamic>> _details = [];
  bool _saving = false;
  @override
  void initState() { super.initState(); final x = widget.initial ?? {}; _remark = TextEditingController(text: '${x['remark'] ?? ''}'); _requestDate = TextEditingController(text: '${x['requestDate'] ?? ''}'); _details = [for (final d in (x['details'] as List? ?? const [])) Map<String, dynamic>.from(d)]; if (_details.isEmpty) _addDetail(); }
  @override
  void dispose() { _remark.dispose(); _requestDate.dispose(); super.dispose(); }
  void _addDetail() => setState(() => _details.add({'itemText': '', 'quantity': null, 'estimatedMin': null, 'estimatedMax': null, 'remark': '', 'neededDate': '', 'urgencyLevel': 0, 'attachments': <dynamic>[] }));
  Future<void> _save() async { if (!_form.currentState!.validate()) return; setState(() => _saving = true); try { final details = [for (final d in _details) Map<String, dynamic>.from(d)..remove('_pending')]; final result = await widget.repository.save({'requestId': widget.initial?['requestId'], 'requestDate': _requestDate.text.trim(), 'remark': _remark.text.trim(), 'statusCode': 'DRAFT', 'details': details}); final upload = purchasingUpload; final requestId = (result['requestId'] as num?)?.toInt(); final ids = List<dynamic>.from(result['detailIds'] as List? ?? const []); if (upload != null && requestId != null) { for (var i = 0; i < _details.length && i < ids.length; i++) { for (final file in List<Map<String, dynamic>>.from(_details[i]['_pending'] as List? ?? const [])) { await upload('/api/purchasing/requests/$requestId/details/${(ids[i] as num).toInt()}/attachments', List<int>.from(file['bytes'] as Uint8List), '${file['name']}', {}); } } } if (mounted) Navigator.pop(context, true); } catch (error) { if (mounted) showPurchasingMessage(context, message: 'บันทึกคำขอจัดซื้อไม่สำเร็จ: $error', error: true); } finally { if (mounted) setState(() => _saving = false); } }
  Future<void> _pickAttachment(Map<String, dynamic> detail) async { final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true, type: FileType.any); if (result == null) return; final pending = List<Map<String, dynamic>>.from(detail['_pending'] as List? ?? const []); for (final file in result.files) { if (file.bytes != null) pending.add({'name': file.name, 'bytes': file.bytes}); } setState(() => detail['_pending'] = pending); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('คำขอจัดซื้อ'),
        content: SizedBox(width: 900, child: Form(key: _form, child: ListView(shrinkWrap: true, children: [
          Row(children: [Expanded(child: TextFormField(controller: _requestDate, decoration: const InputDecoration(labelText: 'วันที่ขอ'), validator: (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุวันที่ขอ' : null)), const SizedBox(width: 12), const Expanded(child: Text('สถานะ: DRAFT'))]),
          TextFormField(controller: _remark, maxLines: 2, decoration: const InputDecoration(labelText: 'หมายเหตุ')),
          const SizedBox(height: 12),
          Row(children: [const Expanded(child: Text('รายการจัดซื้อ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), OutlinedButton.icon(onPressed: _addDetail, icon: const Icon(Icons.add), label: const Text('เพิ่มรายการ'))]),
          ..._details.asMap().entries.map((entry) => _detailCard(entry.key, entry.value)),
        ]))),
        actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('ยกเลิก')), FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('บันทึก Draft'))],
      );
  Widget _detailCard(int index, Map<String, dynamic> d) => Card(margin: const EdgeInsets.only(top: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text('รายการที่ ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(onPressed: _details.length == 1 ? null : () => setState(() => _details.removeAt(index)), icon: const Icon(Icons.delete_outline))]),
    TextFormField(initialValue: '${d['itemText'] ?? ''}', maxLength: 2000, decoration: const InputDecoration(labelText: 'รายการ *'), validator: (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุรายการ' : null, onChanged: (v) => d['itemText'] = v),
    Row(children: [Expanded(child: _number(d, 'quantity', 'จำนวน')), const SizedBox(width: 8), Expanded(child: _number(d, 'estimatedMin', 'ราคาต่ำสุด')), const SizedBox(width: 8), Expanded(child: _number(d, 'estimatedMax', 'ราคาสูงสุด'))]),
    Row(children: [Expanded(child: TextFormField(initialValue: '${d['neededDate'] ?? ''}', decoration: const InputDecoration(labelText: 'วันที่ต้องการ'), onChanged: (v) => d['neededDate'] = v)), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<int>(value: (d['urgencyLevel'] as num?)?.toInt() ?? 0, decoration: const InputDecoration(labelText: 'ระดับความต้องการ'), items: const [DropdownMenuItem(value: 0, child: Text('ปกติ')), DropdownMenuItem(value: 1, child: Text('ด่วน')), DropdownMenuItem(value: 2, child: Text('ด่วนมาก'))], onChanged: (v) => d['urgencyLevel'] = v ?? 0))]),
    TextFormField(initialValue: '${d['remark'] ?? ''}', decoration: const InputDecoration(labelText: 'หมายเหตุรายการ'), onChanged: (v) => d['remark'] = v),
    const SizedBox(height: 4),
    OutlinedButton.icon(onPressed: () => _pickAttachment(d), icon: const Icon(Icons.attach_file), label: const Text('แนบรูป/เอกสาร')),
    ...List<Map<String, dynamic>>.from(d['_pending'] as List? ?? const []).map((file) => ListTile(dense: true, leading: const Icon(Icons.insert_drive_file_outlined), title: Text('${file['name']}'), subtitle: const Text('ไฟล์แนบของรายการนี้'))),
  ])));
  Widget _number(Map<String, dynamic> d, String key, String label) => TextFormField(initialValue: d[key]?.toString() ?? '', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label), onChanged: (v) => d[key] = double.tryParse(v));
}
