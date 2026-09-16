import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';

class LeaveBalancePage extends StatefulWidget {
  const LeaveBalancePage({required this.mine, super.key});
  final bool mine;

  @override
  State<LeaveBalancePage> createState() => _LeaveBalancePageState();
}

class _LeaveBalancePageState extends State<LeaveBalancePage> {
  final _search = TextEditingController();
  late final JsonApiClient _api;
  List<Map<String, dynamic>> _items = const [];
  String? _caption;
  String? _message;
  bool _loading = true;
  bool _canGenerate = false;
  bool _generating = false;

  @override
  void initState() { super.initState(); _api = createTimeApiClient(); _load(); }
  @override
  void dispose() { _search.dispose(); disposeTimeApiClient(_api); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final mine = widget.mine.toString();
      final actions = Map<String, dynamic>.from(await _api.get('/api/time/leave-balances/actions', query: {'mine': mine}) as Map);
      final result = Map<String, dynamic>.from(await _api.get('/api/time/leave-balances', query: {'mine': mine, if (_search.text.trim().isNotEmpty) 'search': _search.text.trim()}) as Map);
      if (!mounted) return;
      setState(() { _caption = actions['caption'] as String?; _canGenerate = actions['generate'] == true; _items = (result['items'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList(growable: false); });
    } catch (error) { if (mounted) setState(() => _message = timeErrorText(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _generate() async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => TimeActionDialog(icon: Icons.auto_awesome_outlined, title: 'ประมวลผลสิทธิ์ลา', content: const Text('ระบบจะสร้างสิทธิ์ตามเกณฑ์ที่มีผล สำหรับพนักงานในขอบเขตที่คุณดูแล และจะไม่สร้างซ้ำจากเกณฑ์ Version เดิม'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ประมวลผล'))]));
    if (confirmed != true || !mounted) return;
    setState(() => _generating = true);
    try { final result = Map<String, dynamic>.from(await _api.post('/api/time/leave-balances/generate', body: {}) as Map); if (mounted) setState(() => _message = 'ประมวลผลสิทธิ์สำเร็จ ${result['generatedCount']} รายการ'); await _load(); } catch (error) { if (mounted) setState(() => _message = timeErrorText(error)); } finally { if (mounted) setState(() => _generating = false); }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    ListView(padding: const EdgeInsets.all(16), children: [
      TimeCaptionCard(icon: Icons.account_balance_wallet_outlined, caption: _caption ?? ''),
      const SizedBox(height: 6),
      if (!widget.mine && _canGenerate) Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined), label: const Text('ประมวลผลสิทธิ์'))),
      if (!widget.mine && _canGenerate) const SizedBox(height: 6),
      if (!widget.mine) Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: _search, onSubmitted: (_) => _load(), decoration: const InputDecoration(labelText: 'ค้นหาพนักงานหรือประเภทการลา', prefixIcon: Icon(Icons.search)))), const SizedBox(width: 12), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.search), label: const Text('ค้นหา'))]))),
      if (!widget.mine) const SizedBox(height: 6),
      Card(child: _loading ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())) : _items.isEmpty ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('ไม่พบข้อมูลสิทธิ์ลา'))) : DataTable(columns: [if (!widget.mine) const DataColumn(label: Text('พนักงาน')), const DataColumn(label: Text('ประเภทการลา')), const DataColumn(label: Text('คงเหลือ'), numeric: true)], rows: _items.map((x) => DataRow(cells: [if (!widget.mine) DataCell(Text('${x['employeeCode']} — ${x['fullName']}')), DataCell(Text('${x['leaveTypeCode']} — ${x['leaveTypeName']}')), DataCell(Text('${x['balance']} ${x['unitCode'] == 'DAY' ? 'วัน' : 'นาที'}'))])).toList())),
    ]),
    if (_message != null) Positioned(top: 16, right: 16, child: buildTimeMessage(message: _message!, error: true, onClose: () => setState(() => _message = null))),
  ]);
}
