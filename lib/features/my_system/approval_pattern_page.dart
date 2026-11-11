import 'package:flutter/material.dart';
import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class ApprovalPatternPage extends StatefulWidget {
  const ApprovalPatternPage({super.key});
  @override
  State<ApprovalPatternPage> createState() => _ApprovalPatternPageState();
}

class _ApprovalPatternPageState extends State<ApprovalPatternPage> {
  final _api = ApiClient();
  final _levels = TextEditingController(text: '1');
  final _positions = <String, String>{};
  final _steps = <Map<String, dynamic>>[];
  bool _loading = true, _canEdit = false;
  String? _error;
  String _title = 'รูปแบบการอนุมัติ';
  @override
  void initState() {
    super.initState();
    _load();
    _loadTitle();
  }

  Future<void> _loadTitle() async {
    final menu = await NavigationMenuRepository().findMenu(menuCode: '10011');
    if (mounted && menu != null) setState(() => _title = menu.name);
  }

  @override
  void dispose() {
    _api.dispose();
    _levels.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/api/company/approval-pattern');
      if (data is! Map ||
          data['steps'] is! List ||
          data['positions'] is! List) {
        throw StateError('Invalid response');
      }
      if (!mounted) return;
      setState(() {
        _levels.text = '${data['levelsUp'] ?? 1}';
        _canEdit = data['canEdit'] == true;
        _positions.clear();
        for (final p in (data['positions'] as List).whereType<Map>()) {
          _positions['${p['code']}'] = '${p['name']}';
        }
        _steps.clear();
        for (final s in (data['steps'] as List).whereType<Map>()) {
          _steps.add({
            'condition': '${s['condition']}',
            'positions': (s['positions'] as List)
                .whereType<Map>()
                .map(
                  (p) => <String, dynamic>{
                    'code': '${p['code']}',
                    'unitScope': '${p['unitScope']}',
                  },
                )
                .toList(),
          });
        }
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'ไม่สามารถโหลดรูปแบบการอนุมัติได้';
        });
      }
    }
  }

  bool _savingLevels = false, _savingSteps = false;

  Future<void> _saveLevels() async {
    final levels = int.tryParse(_levels.text.trim());
    if (levels == null || levels <= 0) {
      showTimedSnackBar(
        context,
        message: 'กรุณาระบุจำนวนระดับเป็นจำนวนเต็มมากกว่า 0',
        error: true,
      );
      return;
    }
    setState(() => _savingLevels = true);
    try {
      await _api.put(
        '/api/company/approval-pattern/levels',
        body: {'levelsUp': levels},
      );
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกจำนวนระดับเรียบร้อยแล้ว');
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกจำนวนระดับไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _savingLevels = false);
    }
  }

  Future<void> _saveSteps() async {
    final codes = _steps
        .expand((s) => (s['positions'] as List).cast<Map<String, dynamic>>())
        .map((p) => '${p['code'] ?? ''}'.trim())
        .toList();
    if (_steps.any((s) => (s['positions'] as List).isEmpty) ||
        codes.any((c) => c.isEmpty) ||
        codes.map((c) => c.toLowerCase()).toSet().length != codes.length) {
      showTimedSnackBar(
        context,
        message: 'กรุณาระบุตำแหน่งให้ครบ โดยตำแหน่งห้ามซ้ำกัน',
        error: true,
      );
      return;
    }
    setState(() => _savingSteps = true);
    try {
      await _api.put(
        '/api/company/approval-pattern/steps',
        body: {'steps': _steps},
      );
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกลำดับตำแหน่งเรียบร้อยแล้ว');
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกลำดับไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _savingSteps = false);
    }
  }

  Widget _step(int index) {
    final item = _steps[index];
    final positions = (item['positions'] as List).cast<Map<String, dynamic>>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'ลำดับ ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  tooltip: 'เลื่อนขึ้น',
                  onPressed: !_canEdit || _savingSteps || index == 0
                      ? null
                      : () => setState(() {
                          final x = _steps.removeAt(index);
                          _steps.insert(index - 1, x);
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'เลื่อนลง',
                  onPressed:
                      !_canEdit || _savingSteps || index == _steps.length - 1
                      ? null
                      : () => setState(() {
                          final x = _steps.removeAt(index);
                          _steps.insert(index + 1, x);
                        }),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'ลบลำดับ',
                  onPressed: !_canEdit || _savingSteps
                      ? null
                      : () => setState(() => _steps.removeAt(index)),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: item['condition'] as String,
              decoration: ocrInput(context, 'เงื่อนไขการอนุมัติ'),
              items: const [
                DropdownMenuItem(
                  value: 'ANY',
                  child: Text('อนุมัติอย่างน้อย 1 ตำแหน่ง'),
                ),
                DropdownMenuItem(
                  value: 'ALL',
                  child: Text('ต้องอนุมัติครบทุกตำแหน่ง'),
                ),
              ],
              onChanged: !_canEdit || _savingSteps
                  ? null
                  : (v) => setState(() => item['condition'] = v),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < positions.length; i++) ...[
              const Divider(thickness: .6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      initialValue: _positions.containsKey(positions[i]['code'])
                          ? positions[i]['code'] as String
                          : null,
                      decoration: ocrInput(context, 'ตำแหน่งงาน'),
                      items: _positions.entries
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.key,
                              child: Text(
                                p.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: !_canEdit || _savingSteps
                          ? null
                          : (v) => setState(() => positions[i]['code'] = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          positions[i]['unitScope'] as String? ?? 'ANY',
                      decoration: ocrInput(context, 'หน่วยงาน'),
                      items: const [
                        DropdownMenuItem(
                          value: 'ANY',
                          child: Text('ทุกหน่วยงาน'),
                        ),
                        DropdownMenuItem(
                          value: 'DEPARTMENT',
                          child: Text('แผนกเดียวกัน'),
                        ),
                        DropdownMenuItem(
                          value: 'DIVISION',
                          child: Text('ฝ่ายเดียวกัน'),
                        ),
                      ],
                      onChanged: !_canEdit || _savingSteps
                          ? null
                          : (v) =>
                                setState(() => positions[i]['unitScope'] = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ลบตำแหน่ง',
                    onPressed: !_canEdit || _savingSteps
                        ? null
                        : () => setState(() => positions.removeAt(i)),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: !_canEdit || _savingSteps
                    ? null
                    : () => setState(
                        () => positions.add({'code': null, 'unitScope': 'ANY'}),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มตำแหน่ง'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _title,
    activeMenu: '10011',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspacePageTitle(title: _title, favoriteKey: '10011'),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    children: [
                      WorkspaceSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ตามระดับตำแหน่งขึ้นไป',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 250,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 250,
                                  child: TextField(
                                    controller: _levels,
                                    enabled: _canEdit && !_savingLevels,
                                    keyboardType: TextInputType.number,
                                    decoration: ocrInput(context, 'จำนวนระดับ'),
                                  ),
                                ),
                              ),
                            ),
                            if (_canEdit) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savingLevels ? null : _saveLevels,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('บันทึก'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: LaooLayout.cardSpacing),
                      WorkspaceSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ตามตำแหน่งงาน',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (_steps.isEmpty)
                              const Text('ยังไม่ได้กำหนดลำดับ'),
                            for (var i = 0; i < _steps.length; i++) _step(i),
                            if (_canEdit)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _savingSteps
                                      ? null
                                      : () => setState(
                                          () => _steps.add({
                                            'condition': 'ANY',
                                            'positions':
                                                <Map<String, dynamic>>[],
                                          }),
                                        ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('เพิ่มลำดับ'),
                                ),
                              ),
                            const Divider(thickness: .6),
                            const Text(
                              'หมายเหตุ: ตำแหน่งของผู้บันทึกและตำแหน่งที่ว่างจะถูกข้าม หากมีตำแหน่งอื่นในลำดับเดียวกัน ระบบจะส่งให้ตำแหน่งที่เหลือ',
                            ),
                            if (_canEdit) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savingSteps ? null : _saveSteps,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('บันทึก'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
