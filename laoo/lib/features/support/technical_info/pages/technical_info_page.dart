import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/technical_info_repository.dart';

class TechnicalInfoPage extends StatefulWidget {
  const TechnicalInfoPage({super.key});
  @override State<TechnicalInfoPage> createState() => _TechnicalInfoPageState();
}

class _TechnicalInfoPageState extends State<TechnicalInfoPage> {
  final _query = TextEditingController();
  final _repository = TechnicalInfoRepository();
  TechnicalInfoResult? _result;
  bool _loading = false;
  String? _error;

  @override void initState() { super.initState(); _search(); }
  @override void dispose() { _query.dispose(); super.dispose(); }
  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try { final value = await _repository.search(_query.text.trim()); if (mounted) setState(() => _result = value); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'ข้อมูลด้านเทคนิค', activeMenu: 'technicalInfo',
    child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WorkspacePageTitle(title: 'ข้อมูลด้านเทคนิค', favoriteKey: 'technicalInfo'),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: const InputDecoration(labelText: 'ค้นหาชื่อเมนู หรือข้อกำหนด'))), const SizedBox(width: 10), FilledButton(onPressed: _loading ? null : _search, child: const Text('ค้นหา'))]),
      const SizedBox(height: 16),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (_loading) const LinearProgressIndicator(),
      if (_result != null && !_loading) ...[
        Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: _copyAll, child: const Text('Copy'))),
        const SizedBox(height: 4),
        Expanded(child: ListView(children: [_section('ข้อมูลเมนู', 'รายละเอียดเมนูที่ใช้งาน', _result!.menus.map((x) => '${x['menuName']} (${x['menuCode']})').toList()), _mdSection(), _section('Table ที่ใช้จัดเก็บข้อมูล', 'แสดงเฉพาะชื่อ Table และความหมายของ Table', _result!.tables.map((x) => '${x['tableName']} — ${x['tableMeaning']}').toList())])),
      ],
    ])),
  );

  Widget _section(String title, String meaning, List<String> values) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))), if (values.isNotEmpty) OutlinedButton(onPressed: () => _copyText(values.join('\n')), child: const Text('Copy'))]), Text(meaning, style: const TextStyle(fontSize: LaooTypography.inputHint)), const SizedBox(height: 10), if (values.isEmpty) const Text('ไม่พบข้อมูล') else ...values.map((v) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(v)))])));

  Widget _mdSection() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: Text('MD ที่เกี่ยวข้อง', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))), if (_result!.mds.isNotEmpty) OutlinedButton(onPressed: () => _copyText(_result!.mds.map((md) => '${md['mdName']} (${md['mdCode']})\n${md['mdPath']}\\${md['mdFileName']}').join('\n')), child: const Text('Copy'))]), const Text('เอกสารและส่วนของไฟล์ที่พบคำค้น'), const SizedBox(height: 10), if (_result!.mds.isEmpty) const Text('ไม่พบข้อมูล') else ..._result!.mds.map((md) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${md['mdName']} (${md['mdCode']})', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${md['mdPath']}\\${md['mdFileName']}'), if ((md['parts'] as List?)?.isNotEmpty ?? false) ...((md['parts'] as List).take(5).map((part) => Text('บรรทัด ${part['line']}: ${part['text']}')))])))])));

  String _allText() {
    final menus = _result!.menus.map((x) => '${x['menuName']} (${x['menuCode']})').join('\n');
    final mds = _result!.mds.map((md) => '${md['mdName']} (${md['mdCode']})\n${md['mdPath']}\\${md['mdFileName']}').join('\n');
    final tables = _result!.tables.map((x) => '${x['tableName']} — ${x['tableMeaning']}').join('\n');
    return 'ข้อมูลเมนู\n$menus\n\nMD ที่เกี่ยวข้อง\n$mds\n\nTable ที่ใช้จัดเก็บข้อมูล\n$tables';
  }

  Future<void> _copyAll() => _copyText(_allText());

  Future<void> _copyText(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คัดลอกข้อมูลแล้ว')));
  }
}
